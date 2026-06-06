const FS_FLOW = [
  ["Mount", "The boot BPB is validated, FAT type is selected, and root/data/FAT regions are derived once per active drive."],
  ["Resolve", "Paths are drive-aware, case-folded into 8.3 names, and walked from the current directory or root."],
  ["Locate", "Directory scans read root entries from ROOT_SEG and subdirectories through SEC_BUF while following FAT chains."],
  ["Transfer", "Cluster numbers become LBAs, sector I/O retries BIOS calls, and reads use READ_CACHE_BUF."],
  ["Commit", "Creates, truncates, deletes, renames, and directory growth flush directory slots and FAT copies in order."],
];

const FS_BUFFERS = [
  ["FAT_SEG 0060", "Whole FAT12 table, or the current FAT16 sector workspace when following chains."],
  ["SEC_BUF 0B00", "One-sector scratch buffer for subdirectories, write-modify-write, and load copies."],
  ["READ_CACHE_BUF 0B20", "AH=3Fh read cache, invalidated by every sector write."],
  ["ROOT_SEG 0B40", "Resident root-directory image for fast root scans and root slot flushes."],
];

const FS_SECTIONS = [
  {
    id: "mount",
    title: "Mount derives the FAT geometry",
    summary: "BPB fields become the working root, data, and cluster limits.",
    body: [
      "LainDOS rejects BPBs that would make later math ambiguous: zero sectors-per-cluster, non-power-of-two cluster sizes, missing reserved/FAT/root geometry, invalid root-entry alignment, and total sectors that cannot cover the data region.",
      "The mount path defaults to FAT12, switches to FAT16 from the BPB type marker, then computes `kfat_start`, `krsta`, `krsc`, `kdsta`, and `kmax_cluster`. Those values are what every later FAT, directory, and disk routine trusts.",
    ],
    file: "src/kernel.asm",
    code: [
      [442, "    mov al, [bx+BPB_SECS_PER_CLUS]"],
      [443, "    test al, al"],
      [447, "    test al, ah"],
      [449, "    cmp word [bx+BPB_RSV_SEC_COUNT], 0"],
      [451, "    cmp byte [bx+BPB_NUM_FATS], 0"],
      [455, "    mov ax, [bx+BPB_ROOT_ENT_COUNT]"],
      [481, "    mov byte [cs:kfat_bits], 12"],
      [485, "    cmp byte [bx+BPB_FS_TYPE+4], '6'"],
      [487, "    mov byte [cs:kfat_bits], 16"],
      [492, "    mov ax, [bx+BPB_SECS_PER_FAT]"],
      [495, "    mov [cs:kfat_start], ax"],
      [505, "    mov [cs:krsta], ax"],
      [525, "    mov [cs:krsc], ax"],
      [528, "    mov [cs:kdsta], ax"],
      [543, "    sub ax, [cs:kdsta]"],
      [549, "    div cx"],
      [553, "    mov [cs:kmax_cluster], ax"],
    ],
    hi: [442, 481, 487, 505, 528, 553],
    tests: ["scripts/test_bpb_invalid.py", "scripts/test_fat16.py", "scripts/test_partitioned_fat16.py"],
  },
  {
    id: "disk",
    title: "Clusters become BIOS sectors",
    summary: "Data-cluster LBAs flow through partition offsets and CHS bounds checks.",
    body: [
      "`cluster_lba` is the only normal path from a FAT cluster number to a sector address. It rejects cluster zero/one and clusters at or beyond `kmax_cluster`, then multiplies by sectors-per-cluster and adds the data start.",
      "Sector I/O adds the partition-relative LBA, retries INT 13h calls, invalidates the read cache on writes, and advances ES across 64 KiB wrap. Geometry errors fail closed instead of letting high-LBA tests read or write the wrong sector.",
    ],
    file: "src/kernel/disk.inc",
    code: [
      [1, "cluster_lba:"],
      [3, "    cmp ax, 2"],
      [5, "    cmp ax, [cs:kmax_cluster]"],
      [7, "    sub ax, 2"],
      [9, "    mov cl, [cs:kspc]"],
      [13, "    add ax, [cs:kdsta]"],
      [25, "read_sector:"],
      [30, "write_sector:"],
      [31, "    mov byte [cs:rf_cache_valid], 0"],
      [58, "setup_sector_io:"],
      [63, "    mov ax, [cs:kpart_lba]"],
      [71, "setup_bios_chs:"],
      [78, "    cmp dx, [cs:kbio_spt]"],
      [80, "    div word [cs:kbio_spt]"],
      [85, "    cmp ax, 1024"],
      [104, "finish_sector_io:"],
      [107, "    mov ax, es"],
      [108, "    add ax, 0x1000"],
    ],
    hi: [1, 5, 13, 31, 63, 85, 108],
    tests: ["scripts/test_fat16_large.py", "scripts/test_fat16_seek.py", "scripts/test_highdir.py"],
  },
  {
    id: "fat",
    title: "FAT chains are bounded and mirrored",
    summary: "FAT12 uses the resident FAT buffer; FAT16 pages sectors through scratch I/O.",
    body: [
      "FAT12 entries are packed 12-bit values in `FAT_SEG`, so odd clusters shift by four and even clusters mask to 0FFFh. FAT16 entries are sector-addressed because the table can be larger than the resident scratch space.",
      "All chain operations sanitize impossible next-cluster values against reserved and max-cluster bounds. Allocation stores an EOC marker immediately; freeing writes zero entries; flushing writes dirty FAT12 tables to every copy, while FAT16 writes each changed sector to each FAT copy at set time.",
    ],
    file: "src/kernel/fat.inc",
    code: [
      [1, "fat_next:"],
      [4, "    cmp si, [cs:kmax_cluster]"],
      [6, "    cmp byte [cs:kfat_bits], 16"],
      [13, "    mov ax, FAT_SEG"],
      [17, "    test si, 1"],
      [19, "    shr ax, 4"],
      [22, "    and ax, 0x0FFF"],
      [24, "    call fat_next_sanitize"],
      [44, "fat16_next:"],
      [55, "    cmp ax, [cs:kfat_secs]"],
      [57, "    add ax, [cs:kfat_start]"],
      [62, "    cmp byte [cs:fat16_cache_valid], 1"],
      [67, "    mov dx, FAT_SEG"],
      [70, "    call read_sector"],
      [75, ".have_sector:"],
      [79, "    mov ax, [bx]"],
      [93, "fat_set:"],
      [98, "    cmp byte [cs:kfat_bits], 16"],
      [128, "    mov byte [cs:fat_dirty], 1"],
      [137, "fat16_set:"],
      [156, "    mov byte [cs:fat_copy_idx], 0"],
      [171, "    call read_sector"],
      [175, "    mov [es:bx], ax"],
      [185, "    call write_sector"],
      [199, "fat_alloc_cluster:"],
      [217, "    call fat_next"],
      [227, "    call fat_set"],
      [247, "fat_free_chain:"],
      [261, "    call fat_set"],
      [275, "flush_fat:"],
      [278, "    cmp byte [cs:kfat_bits], 16"],
      [305, "    mov ax, [cs:kfat_start]"],
      [322, "    call write_sector"],
    ],
    hi: [1, 44, 93, 137, 199, 247, 275],
    tests: ["scripts/test_badfat.py", "scripts/test_fat16_bounds.py", "scripts/test_dirmut.py"],
  },
  {
    id: "paths",
    title: "Paths become 8.3 directory keys",
    summary: "Drive prefixes, relative roots, dot segments, and case folding meet in name_buf.",
    body: [
      "A path first activates the requested drive, then chooses a starting directory. Leading separators force root, drive-qualified relative paths keep that drive's current directory, and plain relative paths start from `cur_dir_cluster`.",
      "The parser fills an eleven-byte DOS name with spaces, uppercases each character, moves to byte eight after a dot, and expands wildcards to question marks for find-first/find-next. Parent resolution temporarily terminates the path at the last separator and calls the same resolver on the parent directory.",
    ],
    file: "src/kernel/path_dir.inc",
    code: [
      [923, "resolve_path:"],
      [925, "    call activate_drive_for_path"],
      [929, "    cmp byte [ds:si], '\\'"],[939, "    mov ax, [cs:cur_dir_cluster]"],
      [944, "    mov ax, ROOT_CLUSTER"],
      [947, "    mov ax, [cs:cur_dir_cluster]"],
      [982, ".rp_parse_name:"],
      [991, "    mov di, name_buf"],
      [1047, "    call ascii_upper"],
      [1055, "    mov di, name_buf + 8"],
      [1074, "    call find_in_dir"],
      [1076, "    test byte [es:di+11], ATTR_DIR"],
      [1092, "    call find_in_dir"],
      [1727, "parse_83name:"],
      [1736, "    mov di, name_buf"],
      [1737, "    mov cx, 11"],
      [1750, "    call ascii_upper"],
      [1753, "    cmp di, name_buf + 8"],
      [1762, ".pl_dot:"],
      [1764, "    mov di, name_buf + 8"],
      [1772, "    mov byte [es:di], '?'"],
      [1801, "parse_root_path:"],
      [1805, "    call activate_drive_for_path"],
      [1809, "    mov ax, [cs:cur_dir_cluster]"],
      [1823, "    mov [cs:pr_last_sep], bx"],
      [1854, "    mov word [cs:pr_dir_cluster], ROOT_CLUSTER"],
      [1872, "    call resolve_path"],
      [1885, "    call parse_83name"],
    ],
    hi: [923, 944, 1047, 1727, 1772, 1801, 1872],
    tests: ["scripts/test_pathcanon.py", "scripts/test_drivepath.py", "scripts/test_diredge.py", "scripts/test_parsefcb.py"],
  },
  {
    id: "directories",
    title: "Directories scan root and cluster chains",
    summary: "Root entries are resident; subdirectory entries stream through the sector buffer.",
    body: [
      "Root scans index directly into `ROOT_SEG`, derive the backing LBA from `krsta`, and stop on the DOS zero entry. Subdirectory scans read each cluster sector through `SEC_BUF`, skip deleted and volume entries, compare against `name_buf`, then follow `fat_next` to the next directory cluster.",
      "When a subdirectory is full, `find_dir_free` extends it by allocating a new cluster, linking the old tail to it, zeroing every new sector, and flushing the FAT. If zeroing or flushing fails, it rolls the chain back before returning failure.",
    ],
    file: "src/kernel/path_dir.inc",
    code: [
      [1105, "find_in_dir:"],
      [1123, "    mov ax, [cs:fid_cluster]"],
      [1126, "    mov ax, ROOT_SEG"],
      [1129, "    cmp cx, [cs:kroot_entries]"],
      [1140, "    add ax, [cs:krsta]"],
      [1148, "    cmp byte [es:di], 0"],
      [1150, "    cmp byte [es:di], 0xE5"],
      [1161, "    call name_matches"],
      [1186, "    mov dx, SEC_BUF"],
      [1192, "    call read_sector"],
      [1200, "    cmp byte [es:di], 0"],
      [1234, "    call fat_next"],
      [1245, "    mov [cs:ff_entry_lba], ax"],
      [1259, "    mov ax, [es:di+26]"],
      [1350, "find_dir_free:"],
      [1372, "    call cluster_lba"],
      [1377, "    mov dx, SEC_BUF"],
      [1390, "    cmp byte [es:di], 0"],
      [1406, "    call fat_next"],
      [1417, "    call fat_alloc_cluster"],
      [1421, "    call fat_set"],
      [1453, "    call write_sector"],
      [1463, "    call flush_fat"],
      [1475, ".sd_rollback:"],
      [1478, "    call fat_set"],
      [1482, "    call flush_fat"],
    ],
    hi: [1105, 1126, 1186, 1350, 1417, 1475],
    tests: ["scripts/test_findedge.py", "scripts/test_dirextfail.py", "scripts/test_dirextrollback.py"],
  },
  {
    id: "slots",
    title: "Directory slots are loaded and flushed explicitly",
    summary: "Root and subdirectory updates use different buffers but one write contract.",
    body: [
      "`load_dir_slot` remembers the target LBA and offset before choosing the backing buffer. Root slots already live in `ROOT_SEG`; subdirectory slots are read into `SEC_BUF` so callers can modify the entry in place.",
      "`flush_handle_dir_entry` is the close/commit path for size, date, time, and first-cluster metadata. It reloads the slot, stores handle fields into the directory entry, and flushes the exact sector back to disk.",
    ],
    file: "src/kernel/fs.inc",
    code: [
      [1, "dir_lba_root_base:"],
      [4, "    cmp ax, [cs:krsta]"],
      [6, "    cmp ax, [cs:kdsta]"],
      [25, "load_dir_slot:"],
      [29, "    call dir_lba_root_base"],
      [31, "    mov ax, ROOT_SEG"],
      [38, "    mov ax, SEC_BUF"],
      [44, "    call read_sector"],
      [53, "flush_dir_slot:"],
      [79, "flush_dir_sector:"],
      [85, "    call dir_lba_root_base"],
      [88, "    call flush_root_sector"],
      [94, "    mov ax, SEC_BUF"],
      [100, "    call write_sector"],
      [106, "flush_handle_dir_entry:"],
      [115, "    mov ax, [cs:si+handles+H_DIR_LBA]"],
      [126, "    call load_dir_slot"],
      [129, "    call store_handle_dir_fields"],
      [132, "    call flush_dir_slot"],
      [141, "store_handle_dir_fields:"],
      [147, "    mov ax, [cs:si+handles+H_CLUSTER]"],
      [149, "    mov ax, [cs:si+handles+H_SIZE_LO]"],
    ],
    hi: [25, 31, 38, 53, 106, 141],
    tests: ["scripts/test_commit.py", "scripts/test_termflush.py", "scripts/test_savewrite.py"],
  },
  {
    id: "readwrite",
    title: "Reads cache; writes invalidate",
    summary: "Handle I/O keeps cluster walking fast without hiding dirty sectors.",
    body: [
      "Reads convert the current file position to a cluster index and sector-in-cluster, reuse the handle's last-cluster cache when possible, then cache the sector in `READ_CACHE_BUF` until another read needs a different LBA.",
      "Writes allocate a first cluster on demand, extend chains with `wf_get_cluster`, read the target sector into `SEC_BUF`, patch only the requested bytes, write the sector back, and invalidate the read cache. Sparse writes fill the gap with zeroes through the same sector path.",
    ],
    file: "src/kernel/int21.inc",
    code: [
      [2892, "    mov ax, si"],
      [2894, "    call cluster_lba"],
      [2895, "    cmp byte [cs:rf_cache_valid], 1"],
      [2902, "    mov byte [cs:rf_cache_valid], 0"],
      [2909, "    mov dx, READ_CACHE_BUF"],
      [2911, "    call read_sector"],
      [2915, "    mov byte [cs:rf_cache_valid], 1"],
      [2941, "    mov dx, READ_CACHE_BUF"],
      [3076, ".wf_file:"],
      [3095, "    call activate_drive_for_handle"],
      [3129, "    call fat_alloc_cluster"],
      [3148, "    call wf_get_cluster"],
      [3155, "    mov ax, SEC_BUF"],
      [3161, "    call read_sector"],
      [3189, "    call write_sector"],
      [3192, "    mov byte [cs:rf_cache_valid], 0"],
      [3207, "    call fat_alloc_cluster"],
      [3227, "    call wf_get_cluster"],
      [3232, "    call cluster_lba"],
      [3238, "    mov dx, SEC_BUF"],
      [3241, "    call read_sector"],
      [3258, "    mov ax, SEC_BUF"],
      [3276, "    call write_sector"],
      [3281, "    mov byte [cs:rf_cache_valid], 0"],
      [3303, "    mov ax, [cs:wf_written]"],
    ],
    hi: [2895, 2909, 3129, 3192, 3207, 3281],
    tests: ["scripts/test_readcache.py", "scripts/test_rwedge.py", "scripts/test_seekedge.py"],
  },
  {
    id: "mutations",
    title: "Mutations flush directory and FAT state",
    summary: "Create, truncate, delete, rename, and commit keep disk images inspectable after exit.",
    body: [
      "Create and create-new share one path: parse the parent, find an existing entry or free slot, reject open/read-only conflicts, truncate old chains when replacing, write a fresh directory entry, and return a handle bound to that slot.",
      "Delete marks the directory entry E5h before freeing its FAT chain; rename is same-directory only and rejects open/read-only entries; commit and close flush handle metadata and FAT state so host-side image checks see durable data.",
    ],
    file: "src/kernel/int21.inc",
    code: [
      [2295, ".create_file:"],
      [2312, "    call parse_root_path"],
      [2316, "    call find_in_dir"],
      [2319, "    call find_dir_free"],
      [2332, "    call entry_has_open_handle"],
      [2349, "    mov si, [cs:cf_first_cluster]"],
      [2350, "    call fat_free_chain"],
      [2351, "    call flush_fat"],
      [2357, "    call load_dir_slot"],
      [2370, "    mov si, name_buf"],
      [2384, "    call flush_dir_slot"],
      [3371, ".delete_file:"],
      [3379, "    call parse_root_path"],
      [3383, "    call find_in_dir"],
      [3393, "    mov byte [es:di], 0xE5"],
      [3396, "    call flush_dir_slot"],
      [3399, "    call fat_free_chain"],
      [3400, "    call flush_fat"],
      [4441, ".rename_file:"],
      [4452, "    call parse_root_path"],
      [4458, "    call find_in_dir"],
      [4464, "    call entry_has_open_handle"],
      [4478, "    cmp ax, [cs:rn_dir_cluster]"],
      [4492, "    mov si, name_buf"],
      [4497, "    call flush_dir_slot"],
      [4567, ".commit_file:"],
      [4597, "    call flush_handle_dir_entry"],
      [4599, "    call flush_fat"],
    ],
    hi: [2295, 2350, 3371, 3393, 4441, 4567],
    tests: ["scripts/test_createapi.py", "scripts/test_savewrite.py", "scripts/test_dirmut.py", "scripts/test_rnguard.py"],
  },
];

const FS_TESTS = [
  ["BPB", "scripts/test_bpb_invalid.py", "Rejects invalid BPB geometry before mounting."],
  ["FAT16", "scripts/test_fat16.py", "Boots and runs from a FAT16 volume."],
  ["Bounds", "scripts/test_badfat.py", "Rejects bad cluster links without wandering off disk."],
  ["High LBA", "scripts/test_highdir.py", "Reads directories and files beyond low floppy-style sectors."],
  ["Paths", "scripts/test_pathcanon.py", "Checks true-name/path canonicalization and 8.3 behavior."],
  ["Writes", "scripts/test_savewrite.py", "Verifies saved data persists after QEMU exits."],
  ["Mutations", "scripts/test_dirmut.py", "Inspects directory entries and FAT reachability after changes."],
  ["Rollback", "scripts/test_dirextrollback.py", "Forces directory-extension failure and verifies FAT copies."],
];

function FilesystemPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> FAT filesystem track
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Filesystem
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 780, margin: 0 }}>
            How LainDOS turns a FAT12 or FAT16 image into DOS files: BPB validation, cluster math,
            directory traversal, path parsing, read caching, writes, rollback, and durable flushes.
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={fsCard(T)}>
              <h2 style={fsH2(T)}>The FAT path</h2>
              <p style={fsP(T)}>
                LainDOS keeps the filesystem deliberately small: one active volume at a time, 8.3 names,
                FAT12 and FAT16 cluster chains, fixed low-memory buffers, and direct directory-entry writes.
                The tests around this code inspect serial output and disk images because persistence bugs are
                often invisible until QEMU exits.
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {FS_FLOW.map((row, i) => <FsFlow key={row[0]} row={row} index={i} />)}
              </div>
            </section>

            {FS_SECTIONS.map(section => <FsSection key={section.id} section={section} />)}
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={fsPanel(T)}>
              <h3 style={fsKicker(T)}>Filesystem buffers</h3>
              <window.MemoryMap touches={["fat", "sec", "cache", "root"]} compact={true} />
              <div style={{ display: "grid", gap: 8, marginTop: 12 }}>
                {FS_BUFFERS.map(row => <FsBuffer key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...fsPanel(T), marginTop: 14 }}>
              <h3 style={fsKicker(T)}>Regression map</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {FS_TESTS.map(row => <FsTest key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...fsPanel(T), marginTop: 14 }}>
              <h3 style={fsKicker(T)}>Related tracks</h3>
              <button onClick={() => go("boot/s5")} style={{ ...fsButton(T.pink), marginBottom: 8 }}>Boot memory map</button>
              <button onClick={() => go("dosapi")} style={{ ...fsButton(T.amber), marginBottom: 8 }}>INT 21h file APIs</button>
              <button onClick={() => go("tests")} style={fsButton(T.blue)}>Test ladder</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function FsFlow({ row, index }) {
  const T = window.T;
  return (
    <div style={{ display: "grid", gridTemplateColumns: "42px 110px 1fr", gap: 12, alignItems: "baseline",
      border: `1px solid ${T.line}`, borderRadius: 10, background: "#fffdf6", padding: "10px 12px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.faint }}>{String(index + 1).padStart(2, "0")}</code>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.green, textTransform: "uppercase" }}>{row[0]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.5 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function FsSection({ section }) {
  const T = window.T;
  return (
    <section id={section.id} style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap", marginBottom: 8 }}>
        <h2 style={{ ...fsH2(T), margin: 0 }}>{section.title}</h2>
        <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.green }}>{section.summary}</code>
      </div>
      {section.body.map((p, i) => <p key={i} style={fsP(T)}><window.InlineText text={p} /></p>)}
      <div style={{ display: "grid", gap: 14, marginTop: 16, alignItems: "start" }}>
        <window.CodeBlock file={section.file} code={section.code} hi={section.hi} />
        <div style={{ display: "grid", gap: 12 }}>
          <div style={fsPanel(T)}>
            <h3 style={fsKicker(T)}>Tests that pin this</h3>
            <div style={{ display: "grid", gap: 7 }}>
              {section.tests.map(test => <code key={test} style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue }}>{test}</code>)}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function FsBuffer({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "9px 10px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.green }}>{row[0]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 3 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function FsTest({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.green, textTransform: "uppercase" }}>{row[0]}</div>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue }}>{row[1]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[2]} /></div>
    </div>
  );
}

function fsCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function fsPanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function fsH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function fsP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, maxWidth: 760, margin: "0 0 12px" };
}
function fsKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function fsButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { FilesystemPage });
