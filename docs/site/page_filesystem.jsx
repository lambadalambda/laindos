const FS_FLOW = [
  ["Mount", "The boot BPB is validated, FAT type is selected, and root/data/FAT regions are derived once per active drive."],
  ["Resolve", "Paths are drive-aware, case-folded into 8.3 names, and walked from the current directory or root."],
  ["Locate", "Directory scans read root entries from ROOT_SEG and FAT subdirectories through a bounded sector cache copied into SEC_BUF while following FAT chains."],
  ["Transfer", "Cluster numbers become LBAs, sector I/O retries BIOS calls, and sequential reads use READ_CACHE_BUF read-ahead."],
  ["Commit", "Creates, truncates, deletes, renames, and directory growth flush directory slots and FAT copies in order."],
];

const FS_BUFFERS = [
  ["FAT_SEG 0060", "Whole FAT12 table, or the current FAT16 sector workspace when following chains."],
  ["SEC_BUF 0200", "One-sector scratch buffer for subdirectories, write-modify-write, and load copies."],
  ["READ_CACHE_BUF 0220", "Four-sector AH=3Fh read cache, invalidated by writes, seeks, disk reset, and drive switches."],
  ["ROOT_SEG 02A0", "Resident root-directory image for fast root scans and root slot flushes."],
  ["SUBDIR_CACHE_BUF 08C0", "Sixteen-sector FAT subdirectory cache, keyed by drive and LBA and invalidated by writes/media changes."],
];

const FS_SECTIONS = [
  {
    id: "mount",
    title: "Mount derives the FAT geometry",
    summary: "BPB fields become the working root, data, and cluster limits.",
    body: [
      "LainDOS rejects BPBs that would make later math ambiguous: zero sectors-per-cluster, non-power-of-two cluster sizes, missing reserved/FAT/root geometry, invalid root-entry alignment, and total sectors that cannot cover the data region.",
      "The mount path computes `kfat_start`, `krsta`, `krsc`, `kdsta`, and the data-area cluster count, then picks FAT12 or FAT16 from the cluster count itself (fewer than 4085 clusters means FAT12) — the BPB type string is ignored, matching how real DOS decides. Those values are what every later FAT, directory, and disk routine trusts.",
    ],
    file: "src/kernel.asm",
    code: [
      [588, "    mov al, [bx+BPB_SECS_PER_CLUS]"],
      [533, "    test al, al"],
      [537, "    test al, ah"],
      [539, "    cmp word [bx+BPB_RSV_SEC_COUNT], 0"],
      [541, "    cmp byte [bx+BPB_NUM_FATS], 0"],
      [585, "    mov ax, [bx+BPB_ROOT_ENT_COUNT]"],
      [571, "    mov ax, [bx+BPB_SECS_PER_FAT]"],
      [574, "    mov [cs:kfat_start], ax"],
      [584, "    mov [cs:krsta], ax"],
      [604, "    mov [cs:krsc], ax"],
      [607, "    mov [cs:kdsta], ax"],
      [622, "    sub ax, [cs:kdsta]"],
      [628, "    div cx"],
      [632, "    mov [cs:kmax_cluster], ax"],
      [634, "    mov byte [cs:kfat_bits], 12"],
      [638, "    cmp ax, 4087"],
      [640, "    mov byte [cs:kfat_bits], 16"],
    ],
    hi: [584, 634, 640, 584, 607, 628],
    tests: ["scripts/test_bpb_invalid.py", "scripts/test_fat16.py", "scripts/test_partitioned_fat16.py"],
  },
  {
    id: "disk",
    title: "Clusters become BIOS sectors",
    summary: "Data-cluster LBAs flow through partition offsets and CHS bounds checks.",
    body: [
      "`cluster_lba` is the only normal path from a FAT cluster number to a sector address. It rejects cluster zero/one and clusters at or beyond `kmax_cluster`, then multiplies by sectors-per-cluster and adds the data start.",
      "Sector I/O adds the partition-relative LBA, retries INT 13h calls, caps multi-sector reads at track and 64 KiB DMA boundaries, invalidates filesystem sector caches on writes, and advances ES across 64 KiB wrap. Geometry errors fail closed instead of letting high-LBA tests read or write the wrong sector.",
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
      [26, "    mov cx, 1"],
      [28, "read_sectors:"],
      [29, "    call wf_flush_sector_cache"],
      [37, "write_sector: PERF_INC perf_sector_writes"],
      [38, "    call subdir_cache_invalidate"],
      [39, "    mov byte [cs:kio_op], 3"],
      [111, "setup_sector_io:"],
      [116, "    mov ax, [cs:kpart_lba]"],
      [133, "setup_bios_chs:"],
      [140, "    cmp dx, [cs:kbio_spt]"],
      [142, "    div word [cs:kbio_spt]"],
      [190, "    cmp ax, 1024"],
      [211, "finish_sector_io:"],
      [228, "    mov ax, es"],
      [230, "    add ax, 0x1000"],
    ],
    hi: [1, 5, 13, 38, 116, 190, 230],
    tests: ["scripts/test_fat16_large.py", "scripts/test_fat16_seek.py", "scripts/test_highdir.py"],
  },
  {
    id: "fat",
    title: "FAT chains are bounded and mirrored",
    summary: "FAT12 keeps the whole table resident; FAT16 caches one sector in a write-back window.",
    body: [
      "FAT12 entries are packed 12-bit values in `FAT_SEG`, so odd clusters shift by four and even clusters mask to 0FFFh. The whole FAT12 table fits in the resident scratch buffer, so reads and writes touch it in place and a single flush mirrors it to every copy.",
      "FAT16 tables can be far larger than that buffer (an 80 KiB FAT on a 160 MB volume), so both reads and writes go through one cached sector — the write-back window. `fat16_window_load` keeps the requested FAT sector in `FAT_SEG`; if a different sector is already cached and dirty it is flushed to every FAT copy first. `fat16_set` patches the entry in memory and only marks the window dirty, deferring the disk write to the next eviction or to `flush_fat`.",
      "This matters under real-speed hardware: the old FAT16 path read-modify-wrote both FAT copies on every single entry, turning a multi-megabyte file's cluster chain into tens of thousands of sector writes (the Red Alert swap-file stall). The window collapses an entire FAT sector's worth of allocations — 256 entries — into one read and one write per copy. All chain operations still sanitize impossible next-cluster values against reserved and max-cluster bounds.",
    ],
    file: "src/kernel/fat.inc",
    code: [
      [33, "fat_next:"],
      [38, "    cmp byte [cs:kfat_bits], 16"],
      [76, "fat16_next:"],
      [88, "    call fat16_window_load          ; ax = FAT-relative sector"],
      [111, "fat16_window_load:"],
      [158, "fat16_window_flush:"],
      [161, "    cmp byte [cs:fat16_cache_dirty], 1"],
      [191, "    call write_sector"],
      [245, "fat_set:"],
      [297, "fat16_set:"],
      [310, "    call fat16_window_load          ; ax = FAT-relative sector"],
      [317, "    mov [es:bx], ax"],
      [318, "    mov byte [cs:fat16_cache_dirty], 1"],
      [330, "fat_alloc_cluster: PERF_INC perf_fat_allocs"],
      [379, "fat_free_chain:"],
      [410, "flush_fat: PERF_INC perf_fat_flushes"],
      [411, "    cmp byte [cs:kfat_bits], 16"],
      [463, "    call write_sector"],
    ],
    hi: [76, 88, 111, 158, 297, 318, 410],
    tests: ["scripts/test_badfat.py", "scripts/test_fat16_bounds.py", "scripts/test_dirmut.py"],
  },
  {
    id: "paths",
    title: "Paths become 8.3 directory keys",
    summary: "Drive prefixes, relative roots, dot segments, and case folding meet in name_buf.",
    body: [
      "A path first activates the requested drive, then chooses a starting directory. Leading separators force root, drive-qualified relative paths keep that drive's current directory, and plain relative paths start from `cur_dir_cluster`.",
      "The parser fills an eleven-byte DOS name with spaces, uppercases each character, moves to byte eight after a dot, and expands wildcards to question marks for find-first/find-next, including extension wildcards for a name-part `*` without an explicit dot. Parent resolution temporarily terminates the path at the last separator and calls the same resolver on the parent directory while preserving any explicit drive prefix.",
    ],
    file: "src/kernel/path_dir.inc",
    code: [
      [1060, "resolve_path:"],
      [1062, "    call activate_drive_for_path"],
      [1066, "    cmp byte [ds:si], '\\'"],
      [1076, "    mov ax, [cs:cur_dir_cluster]"],
      [1081, "    mov ax, ROOT_CLUSTER"],
      [1084, "    mov ax, [cs:cur_dir_cluster]"],
      [1119, ".rp_parse_name:"],
      [1124, "    mov di, name_buf"],
      [1185, "    call ascii_upper"],
      [1201, "    mov di, name_buf + 8"],
      [1226, "    call find_in_dir"],
      [1228, "    test byte [es:di+11], ATTR_DIR"],
      [1240, "    call find_in_dir"],
      [1861, "parse_83name:"],
      [1870, "    mov di, name_buf"],
      [1871, "    mov cx, 11"],
      [1884, "    call ascii_upper"],
      [1904, "    cmp di, name_buf + 8"],
      [1896, ".pl_dot:"],
      [1917, "    mov di, name_buf + 8"],
      [1921, "    mov byte [es:di], '?'"],
      [1943, "parse_root_path:"],
      [1947, "    call activate_drive_for_path"],
      [1951, "    mov ax, [cs:cur_dir_cluster]"],
      [1965, "    mov [cs:pr_last_sep], bx"],
      [1996, "    mov word [cs:pr_dir_cluster], ROOT_CLUSTER"],
      [2008, "    call resolve_path"],
      [2021, "    call parse_83name"],
    ],
    hi: [1060, 1076, 1185, 1861, 1921, 1917, 2008],
    tests: ["scripts/test_pathcanon.py", "scripts/test_drivepath.py", "scripts/test_diredge.py", "scripts/test_parsefcb.py", "scripts/test_findstar.py"],
  },
  {
    id: "directories",
    title: "Directories scan root and cluster chains",
    summary: "Root entries are resident; subdirectory entries stream through the sector buffer.",
    body: [
      "Root scans index directly into `ROOT_SEG`, derive the backing LBA from `krsta`, and stop on the DOS zero entry. Subdirectory scans read each cluster sector through the subdirectory sector cache into `SEC_BUF`, skip deleted and volume entries, compare against `name_buf`, then follow `fat_next` to the next directory cluster.",
      "When a subdirectory is full, `find_dir_free` extends it by allocating a new cluster, linking the old tail to it, zeroing every new sector, and flushing the FAT. If zeroing or flushing fails, it rolls the chain back before returning failure.",
    ],
    file: "src/kernel/path_dir.inc",
    code: [
      [1270, "find_in_dir:"],
      [1288, "    mov ax, [cs:fid_cluster]"],
      [1291, "    mov ax, ROOT_SEG"],
      [1294, "    cmp cx, [cs:kroot_entries]"],
      [1475, "    add ax, [cs:krsta]"],
      [1305, "    cmp byte [es:di], 0"],
      [1307, "    cmp byte [es:di], 0xE5"],
      [1318, "    call name_matches"],
      [1343, "    LOAD_SUBDIR_SECTOR rid_lba, rid_lba_hi, .rid_notfound_pop"],
      [1346, "    cmp byte [es:di], 0"],
      [1377, "    call fat_next_checked"],
      [1383, "    mov [cs:ff_entry_lba], ax"],
      [1397, "    mov ax, [es:di+26]"],
      [1488, "find_dir_free:"],
      [1511, "    call cluster_lba"],
      [1516, "    LOAD_SUBDIR_SECTOR rid_lba, rid_lba_hi, .sd_full"],
      [1519, "    cmp byte [es:di], 0"],
      [1532, "    call fat_next_checked"],
      [1542, "    call fat_alloc_cluster"],
      [1546, "    call fat_set"],
      [1578, "    call write_sector"],
      [1585, "    call flush_fat"],
      [1597, ".sd_rollback:"],
      [1600, "    call fat_set"],
      [1604, "    call flush_fat"],
    ],
    hi: [1270, 1291, 1343, 1488, 1542, 1597],
    tests: ["scripts/test_findedge.py", "scripts/test_dirextfail.py", "scripts/test_dirextrollback.py", "scripts/test_subdir_cache.py"],
  },
  {
    id: "slots",
    title: "Directory slots are loaded and flushed explicitly",
    summary: "Root and subdirectory updates use different buffers but one write contract.",
    body: [
      "`load_dir_slot` remembers the target LBA and offset before choosing the backing buffer. Root slots already live in `ROOT_SEG`; subdirectory slots are read through the subdirectory cache into `SEC_BUF` so callers can modify the entry in place.",
      "`flush_handle_dir_entry` is the close/commit path for size, date, time, and first-cluster metadata. It reloads the slot, stores handle fields into the directory entry, and flushes the exact sector back to disk.",
      "Close, commit, and file-time updates enter through `flush_dirty_handle_dir_entry`: data is flushed first, then a spare per-handle dirty byte decides whether the directory sector actually needs rewriting.",
    ],
    file: "src/kernel/fs.inc",
    code: [
      [1, "dir_lba_root_base:"],
      [4, "    cmp ax, [cs:krsta]"],
      [6, "    cmp ax, [cs:kdsta]"],
      [25, "load_dir_slot:"],
      [29, "    call dir_lba_root_base"],
      [31, "    mov ax, ROOT_SEG"],
      [38, "    mov dx, [cs:dir_flush_lba_hi]"],
      [40, "    call load_subdir_sector_cached"],
      [47, "flush_dir_slot:"],
      [48, "    call subdir_cache_invalidate"],
      [82, "flush_dir_sector: PERF_INC perf_dir_flushes"],
      [88, "    call dir_lba_root_base"],
      [91, "    call flush_root_sector"],
      [97, "    mov ax, SEC_BUF"],
      [103, "    call write_sector"],
      [109, "flush_handle_dir_entry:"],
      [118, "    mov ax, [cs:si+handles+H_DIR_LBA]"],
      [129, "    call load_dir_slot"],
      [132, "    call store_handle_dir_fields"],
      [135, "    call flush_dir_slot"],
      [144, "store_handle_dir_fields:"],
      [150, "    mov ax, [cs:si+handles+H_CLUSTER]"],
      [152, "    mov ax, [cs:si+handles+H_SIZE_LO]"],
      [159, "flush_dirty_handle_dir_entry:"],
      [160, "    cmp byte [cs:si+handles+H_DRIVE+1], 0"],
      [165, "    call flush_handle_dir_entry"],
      [167, "    mov byte [cs:si+handles+H_DRIVE+1], 0"],
    ],
    hi: [25, 31, 40, 47, 109, 144, 159],
    tests: ["scripts/test_commit.py", "scripts/test_termflush.py", "scripts/test_savewrite.py", "scripts/test_metafail.py", "scripts/test_subdir_cache.py", "scripts/bench_metadata.py"],
  },
  {
    id: "readwrite",
    title: "Reads cache; hard-disk writes coalesce",
    summary: "Handle I/O keeps cluster walking fast while hard-disk writes merge small records.",
    body: [
      "Reads convert the current file position to a cluster index and sector-in-cluster, use a shared FAT chain-position cache when possible, and direct-read aligned full-sector requests of at least two sectors. Smaller sequential reads keep a bounded window in `READ_CACHE_BUF`: non-sequential misses read one sector, while immediate continuation misses prefetch up to four sectors capped by the current FAT cluster and EOF. If the read targets the dirty write-back sector, LainDOS flushes it and fills `READ_CACHE_BUF` from `WRITE_CACHE_BUF` rather than rereading stale media data.",
      "Writes allocate a first cluster on demand, extend chains with `wf_get_cluster`, read partial target sectors into `WRITE_CACHE_BUF`, patch only the requested bytes, and mark that sector dirty. On hard disks the dirty sector is deferred until the next uncached FAT chain walk, another sector, a read, close/commit, disk reset, or drive switch forces a flush; floppy writes flush immediately. Sparse writes allocate FAT chain gaps without zero-filling every sector.",
    ],
    file: "src/kernel/int21.inc",
    code: [
      [1710, "    mov ax, si"],
      [3626, "    call cluster_lba"],
      [3157, "    call read_sectors"],
      [3176, "    cmp byte [cs:rf_cache_valid], 1"],
      [3188, "    cmp cl, [cs:rf_cache_count]"],
      [3218, "    mov byte [cs:rf_cache_count], READ_CACHE_SECTORS"],
      [3220, "    mov cl, [cs:kspc]"],
      [3256, "    call wf_fill_read_cache_from_write"],
      [3266, "    mov dx, READ_CACHE_BUF"],
      [3270, "    call read_sectors"],
      [3302, "    mov dx, [cs:rf_cache_seg]"],
      [3477, ".write_file: PERF_INC perf_write_calls"],
      [3515, "    call activate_drive_for_handle"],
      [2312, "    call fat_alloc_cluster"],
      [3539, "    call wf_flush_sector_cache"],
      [3590, "    call wf_flush_sector_cache"],
      [3593, "    call fat_alloc_cluster"],
      [3615, "    cmp ax, [cs:wf_cluster_index]"],
      [3618, "    call wf_flush_sector_cache"],
      [3621, "    call wf_get_cluster"],
      [3626, "    call cluster_lba"],
      [3629, "    call wf_prepare_sector_cache"],
      [3634, "    mov dx, WRITE_CACHE_BUF"],
      [3645, "    call read_sector"],
      [3663, "    mov ax, WRITE_CACHE_BUF"],
      [3672, "    call wf_mark_sector_cache"],
      [3675, "    call wf_flush_sector_cache"],
      [3779, "    mov ax, [cs:wf_written]"],
    ],
    hi: [3157, 3176, 3218, 3270, 3302, 3539, 3590, 3615, 3618, 3621, 3629, 3672],
    tests: ["scripts/test_readcache.py", "scripts/test_rwedge.py", "scripts/test_seekedge.py"],
  },
  {
    id: "mutations",
    title: "Mutations flush directory and FAT state",
    summary: "Create, truncate, delete, rename, and commit keep disk images inspectable after exit.",
    body: [
      "Create and create-new share one path: parse the parent, find an existing entry or free slot, reject open/read-only conflicts, truncate old chains when replacing, write a fresh directory entry, and return a handle bound to that slot. Fault-injection builds can force a post-allocation `flush_dir_slot` failure and query the handle count through `AH=F0h` to prove the failed create does not leak an open slot.",
      "Delete marks the directory entry E5h before freeing its FAT chain; rename is same-directory only and rejects open/read-only entries; commit and close flush handle metadata and FAT state so host-side image checks see durable data.",
    ],
    file: "src/kernel/int21.inc",
    code: [
      [2450, ".create_file:"],
      [2645, "    call parse_root_path"],
      [2649, "    call find_in_dir"],
      [2481, "    call find_dir_free"],
      [2494, "    call entry_has_open_handle"],
      [2511, "    mov si, [cs:cf_first_cluster]"],
      [2512, "    call fat_free_chain"],
      [2513, "    call flush_fat"],
      [2519, "    call load_dir_slot"],
      [996, "    mov si, name_buf"],
      [2546, "    call flush_dir_slot"],
      [3845, ".delete_file:"],
      [3858, "    call parse_root_path"],
      [3862, "    call find_in_dir"],
      [3872, "    mov byte [es:di], 0xE5"],
      [3875, "    call flush_dir_slot"],
      [3878, "    call fat_free_chain"],
      [3879, "    call flush_fat"],
      [5076, ".rename_file:"],
      [5092, "    call parse_root_path"],
      [5098, "    call find_in_dir"],
      [5104, "    call entry_has_open_handle"],
      [5120, "    cmp ax, [cs:rn_dir_cluster]"],
      [5134, "    mov si, name_buf"],
      [5139, "    call flush_dir_slot"],
      [5206, ".commit_file:"],
      [5236, "    call wf_flush_handle_dir_entry"],
      [5238, "    call flush_fat"],
    ],
    hi: [2450, 2546, 3845, 3879, 5076, 5206],
    tests: ["scripts/test_createapi.py", "scripts/test_handleleak.py", "scripts/test_savewrite.py", "scripts/test_dirmut.py", "scripts/test_rnguard.py"],
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
              <window.MemoryMap touches={["fat", "sec", "cache", "write", "root"]} compact={true} />
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
