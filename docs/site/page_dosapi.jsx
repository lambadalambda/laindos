// page_dosapi.jsx - end-user guide to the INT 21h compatibility surface.

const DOSAPI_GROUPS = [
  {
    id: "console",
    title: "Console and shell basics",
    verdict: "Ready for text-mode installers, utilities, and the LainDOS shell.",
    calls: "AH=01h,02h,06h,07h,08h,09h,0Ah,0Bh,0Ch,0Eh",
    prose: [
      "These calls are the classic DOS way to print strings, read keys, poll the keyboard, and select the current drive. LainDOS routes them through the same console layer that writes to VGA text memory and COM1, so user-visible text also appears in the serial log when useful.",
      "For end users this means simple command-line tools, batch files, and setup programs have the basic terminal behavior they expect. It is not a full ANSI terminal, but it covers the plain DOS console style used by the current test ladder."
    ],
    codeFile: "src/kernel/int21.inc",
    code: [
      [190, "    cmp ah, 0x09"],
      [191, "    je .print_string"],
      [192, "    cmp ah, 0x01"],
      [193, "    je .read_char_echo"],
      [196, "    cmp ah, 0x06"],
      [197, "    je .direct_console_io"],
      [202, "    cmp ah, 0x0A"],
      [203, "    je .read_line_buffered"],
    ],
    regs: [
      ["AH", "function", "console service number"],
      ["DL", "char/drive", "AH=02h prints DL; AH=0Eh selects drive DL"],
      ["CF", "clear", "successful console calls return without carry"],
    ],
    tests: ["scripts/test_console.py", "scripts/test_write.py", "scripts/test_shell.py", "scripts/test_autoexec.py", "scripts/test_multidrive_shell.py"],
  },
  {
    id: "files",
    title: "Files, directories, and save data",
    verdict: "The core file API is in place for real game data and save writes.",
    calls: "AH=39h-43h,56h,57h,5Ah,5Bh,68h",
    prose: [
      "This is the compatibility surface most games hit first: make and remove directories, change directory, create/open/close/read/write/seek files, delete, rename, get or set attributes, get or set file timestamps, create temporary files, create-new, and commit writes.",
      "LainDOS deliberately handles real FAT writeback here: truncating an existing writable file frees its old cluster chain, writes update file size and directory metadata, rename refuses read-only/open files, and commit flushes both the directory entry and FAT."
    ],
    codeFile: "src/kernel/int21.inc",
    code: [
      [222, "    cmp ah, 0x3C"],
      [223, "    je .create_file"],
      [224, "    cmp ah, 0x3D"],
      [225, "    je .open_file"],
      [228, "    cmp ah, 0x3F"],
      [229, "    je .read_file"],
      [230, "    cmp ah, 0x40"],
      [231, "    je .write_file"],
      [304, "    cmp ah, 0x56"],
      [305, "    je .rename_file"],
    ],
    regs: [
      ["DS:DX", "path/buffer", "pathnames for open/create/delete; buffer for read/write"],
      ["BX", "handle", "file handle for close/read/write/seek/time/commit"],
      ["AX", "result", "handle, byte count, or DOS error code if CF is set"],
    ],
    tests: ["scripts/test_savewrite.py", "scripts/test_dirmut.py", "scripts/test_findtime.py", "scripts/test_commit.py"],
  },
  {
    id: "programs",
    title: "Launching programs",
    verdict: "Shell-launched COM/EXE programs, overlays, TSR exits, and PSP probes are supported.",
    calls: "AH=31h,4Bh,4Ch,4Dh,50h,51h,62h",
    prose: [
      "When SHELL.COM starts another program, it uses EXEC. LainDOS loads the child image, builds a PSP, supplies the command tail and child-owned environment, inherits the parent's fixed PSP handle table, applies EXE relocations, and restores the parent after the child exits.",
      "The default environment includes COMSPEC, PATH, PROMPT, and a conventional SB16 BLASTER string so games launched under QEMU's `-device sb16` can detect the emulator-provided sound card.",
      "For users this is why typing `midemo` at A:\\> works instead of needing a direct-boot image. The same path also supports overlay loads, TSR-style keep-process exits used by runtime helpers such as DPMI hosts, and set/get PSP probes used by older runtimes."
    ],
    codeFile: "src/kernel/int21.inc",
    code: [
      [296, "    cmp ah, 0x50"],
      [297, "    je .set_psp"],
      [298, "    cmp ah, 0x51"],
      [299, "    je .get_psp"],
      [1934, ".exec:"],
      [902, "    cmp al, 0"],
      [1963, "    call load_exec_program"],
      [1967, "    call exec_com_dyn"],
      [1970, "    call setup_exe_dyn"],
    ],
    regs: [
      ["AH", "4Bh", "EXEC"],
      ["AL", "00h/03h", "load-and-run program or load overlay"],
      ["ES:BX", "params", "EXEC parameter block supplied by the parent"],
    ],
    tests: ["scripts/test_shell.py", "scripts/test_execparam.py", "scripts/test_spawn.py", "scripts/test_execenv.py", "scripts/test_overlay.py", "scripts/test_tsr.py", "scripts/test_compatapi.py"],
  },
  {
    id: "find",
    title: "FindFirst, FindNext, FCB search, and the DTA",
    verdict: "Directory searches work across the current directory and drive-qualified paths.",
    calls: "AH=11h,12h,1Ah,2Fh,4Eh,4Fh,47h",
    prose: [
      "DOS programs do not get directory listings as one big array. They set a Disk Transfer Area, call FindFirst with a wildcard and attribute mask, then call FindNext until DOS reports no more matches.",
      "LainDOS stores search state in the DTA and understands root paths, subdirectories, drive-qualified relative paths, wildcard attributes, timestamps, and current-directory queries.",
      "Older DOS programs may also use FCB FindFirst/FindNext. LainDOS covers the current-directory 8.3 search path needed by Civilization startup, including extended-FCB attribute masks, returning AL status and a drive byte plus raw directory entry at the DTA."
    ],
    codeFile: "src/kernel/int21.inc",
    code: [
      [210, "    cmp ah, 0x11"],
      [211, "    je .fcb_find_first"],
      [212, "    cmp ah, 0x12"],
      [213, "    je .fcb_find_next"],
      [258, "    cmp ah, 0x1A"],
      [259, "    je .set_dta"],
      [292, "    cmp ah, 0x4E"],
      [293, "    je .find_first"],
      [294, "    cmp ah, 0x4F"],
      [295, "    je .find_next"],
      [615, ".fcb_find_first:"],
      [659, "    call .fcb_store_dta"],
      [4315, "    call store_find_dta"],
      [4353, "    call store_find_dta"],
    ],
    regs: [
      ["DS:DX", "FCB/DTA/path", "FCB for AH=11h/12h; DTA pointer for AH=1Ah; search path for AH=4Eh"],
      ["CX", "attrs", "FindFirst attribute mask"],
      ["AL/CF", "status", "FCB search returns AL=00h/FFh; handle search uses carry clear/set"],
    ],
    tests: ["scripts/test_findnext.py", "scripts/test_findattr.py", "scripts/test_findtime.py", "scripts/test_pathcanon.py", "scripts/test_fcbfind.py"],
  },
  {
    id: "memory",
    title: "Memory allocation",
    verdict: "Conventional-memory allocation is backed by a real MCB chain.",
    calls: "AH=48h,49h,4Ah,58h,67h",
    prose: [
      "DOS games ask for memory in 16-byte paragraphs. LainDOS tracks those allocations with Memory Control Blocks, supports allocate/free/resize, and exposes allocation strategy so programs that probe DOS behavior see plausible first-fit, best-fit, and last-fit behavior.",
      "This matters for older games and utilities that inspect the largest executable program size, allocate temporary buffers, or expect parent and child processes to release their memory cleanly."
    ],
    codeFile: "src/kernel/int21.inc",
    code: [
      [246, "    cmp ah, 0x48"],
      [247, "    je .alloc_mem"],
      [248, "    cmp ah, 0x49"],
      [249, "    je .free_mem"],
      [250, "    cmp ah, 0x4A"],
      [251, "    je .resize_mem"],
      [1230, ".alloc_strategy:"],
      [1243, "    cmp al, 0"],
      [1255, "    mov [cs:alloc_strat], bl"],
    ],
    regs: [
      ["BX", "paras", "paragraph count for allocate/resize"],
      ["AX", "segment", "allocated block segment on success"],
      ["BL", "strategy", "AH=58h set allocation strategy"],
    ],
    tests: ["scripts/test_highmcb.py", "scripts/test_stratapi.py", "scripts/test_memfail.py", "scripts/test_free.py"],
  },
  {
    id: "devices",
    title: "Device names and IOCTL",
    verdict: "Common DOS device checks and standard handles are implemented.",
    calls: "AH=44h,45h,46h plus CON/NUL/AUX/PRN/EMM handles",
    prose: [
      "Programs often ask DOS whether a handle is a character device, whether input is ready, whether output can proceed, or whether a drive is removable/local. Those checks go through IOCTL rather than normal file reads.",
      "LainDOS answers the IOCTL functions used by the current suite and maps DOS device names so tools can open `CON`, write to `NUL`, duplicate handles, or detect console readiness without creating fake files on disk."
    ],
    codeFile: "src/kernel/int21.inc",
    code: [
      [3708, ".ioctl:"],
      [3723, "    cmp al, 0"],
      [3724, "    je .ioctl_get"],
      [1267, "    cmp al, 6"],
      [3728, "    je .ioctl_input_status"],
      [480, "    cmp al, 8"],
      [3732, "    je .ioctl_removable_drive"],
      [3777, "    mov dx, 0x80D3"],
    ],
    regs: [
      ["AL", "subfunc", "IOCTL subfunction"],
      ["BX", "handle", "handle being queried"],
      ["DX", "flags", "device/drive information on success"],
    ],
    tests: ["scripts/test_devnames.py", "scripts/test_ioctlstat.py", "scripts/test_ioctlext.py", "scripts/test_dup.py", "scripts/test_jft.py"],
  },
  {
    id: "version",
    title: "Version, drive data, date/time, and probes",
    verdict: "Compatibility probes return stable DOS-like answers or explicit unsupported-LFN status.",
    calls: "AH=19h,1Bh,1Ch,25h,29h,2Ah-30h,33h,35h,36h,38h,52h,54h,5Dh,60h,63h,71h",
    prose: [
      "Many programs do not immediately open files. They first ask DOS what version it is, what drive is current, how much disk space is free, what the date/time is, or where an interrupt vector points.",
      "LainDOS answers these probes with DOS 3.30-style behavior where that helps old games, returns real disk-free counts from the FAT, keeps enough vector/date/verify state for installers and utilities to continue, and includes narrow FCB compatibility used by older probes and launchers.",
      "Newer DOS-extender runtimes also hit internal and Windows-era compatibility probes. LainDOS now canonicalizes truename paths, returns a minimal DOS swappable-data-area pointer for `AX=5D06h`, and reports unsupported long-filename APIs with `AX=7100h` so DJGPP-style callers can fall back to 8.3 searches."
    ],
    codeFile: "src/kernel/int21.inc",
    code: [
      [280, "    cmp ah, 0x30"],
      [281, "    je .get_version"],
      [286, "    cmp ah, 0x35"],
      [287, "    je .get_vector"],
      [288, "    cmp ah, 0x36"],
      [289, "    je .get_disk_free"],
      [316, "    cmp ah, 0x5D"],
      [317, "    je .dos_internal"],
      [328, "    cmp ah, 0x71"],
      [329, "    je .lfn_unsupported"],
      [829, ".get_version:"],
      [830, "    mov ax, 0x1E03"],
    ],
    regs: [
      ["AX", "1E03h", "AL=03h, AH=1Eh reports DOS version 3.30"],
      ["DL", "drive", "0=current, 1=A:, 2=B:, etc. for drive queries"],
      ["ES:BX", "vector", "AH=35h returns interrupt vector pointer"],
    ],
    tests: ["scripts/test_versionapi.py", "scripts/test_diskfree.py", "scripts/test_datetime.py", "scripts/test_drivedata.py", "scripts/test_multidrive.py", "scripts/test_dbcs.py", "scripts/test_compatapi.py"],
  },
];

const DOSAPI_DEFERRED = [
  "Networking, redirectors, SHARE/locking, printing, CONFIG.SYS device drivers, and full country-table behavior are outside the current game target set.",
  "FCB compatibility is intentionally narrow: filename parsing plus current-directory FCB FindFirst/FindNext are covered, but modern handle APIs are the primary supported file path.",
  "When an unsupported INT 21h function appears, LainDOS logs it over COM1 and returns carry set with a DOS-style error where practical."
];

const DOSAPI_CALLS = [
  {
    title: "Console, keyboard, and drive selection",
    rows: [
      ["00h", "Terminate program", "supported", "Same termination path as INT 20h; AL becomes the stored return code."],
      ["01h", "Read char with echo", "supported", "Blocks for a key and echoes normal characters to the console."],
      ["02h", "Write character", "supported", "Writes DL to the LainDOS console."],
      ["06h", "Direct console I/O", "supported", "DL=FFh polls/reads with ZF status; other DL values print one character."],
      ["07h", "Direct char input", "supported", "Reads a key without echo."],
      ["08h", "Char input without echo", "supported", "Reads a key without echo."],
      ["09h", "Print `$` string", "supported", "Prints DS:DX until `$`, the classic DOS string output call."],
      ["0Ah", "Buffered line input", "supported", "Fills the DOS line buffer, including backspace handling and the final CR."],
      ["0Bh", "STDIN status", "supported", "Returns FFh when console input is waiting, 00h otherwise."],
      ["0Ch", "Flush input then read", "supported", "Clears pending input and dispatches the requested console read function."],
      ["0Eh", "Select default drive", "supported", "Updates the current mounted drive letter and returns the drive count."],
    ],
  },
  {
    title: "Drive, DTA, country, version, and probes",
    rows: [
      ["19h", "Get current drive", "supported", "Returns AL=0 for A:, 1 for B:, etc."],
      ["1Ah", "Set DTA", "supported", "Stores DS:DX as the Disk Transfer Area for find calls."],
      ["1Bh", "Default drive data", "supported", "Returns FAT layout data for the current drive."],
      ["1Ch", "Drive data", "supported", "Returns FAT layout data for a requested drive."],
      ["25h", "Set interrupt vector", "supported", "Writes an IVT entry from DS:DX."],
      ["29h", "Parse filename into FCB", "narrow", "Covers parser semantics used by compatibility probes; handle APIs are preferred."],
      ["2Ah", "Get date", "supported", "Returns the stored DOS date and weekday."],
      ["2Bh", "Set date", "supported", "Accepts valid 1980-2099 dates and recomputes weekday."],
      ["2Ch", "Get time", "supported", "Uses BIOS ticks until a DOS time has been set."],
      ["2Dh", "Set time", "supported", "Stores a DOS-visible time after range validation."],
      ["2Eh", "Set verify flag", "compat", "Stores the flag; disk writes are still explicit in LainDOS."],
      ["2Fh", "Get DTA", "supported", "Returns ES:BX for the current DTA."],
      ["30h", "Get DOS version", "supported", "Reports DOS 3.30 style identity."],
      ["31h", "Terminate and stay resident", "partial", "Keeps the PSP MCB resident, frees non-resident child-owned MCBs, and reports TSR return type."],
      ["33h", "Ctrl-Break state", "partial", "Supports get/set break flag, boot drive query, and true-version query."],
      ["35h", "Get interrupt vector", "supported", "Reads an IVT entry into ES:BX."],
      ["36h", "Get disk free space", "supported", "Counts free clusters from the real FAT."],
      ["38h", "Country information", "partial", "Returns a small default country table and accepts country 1."],
      ["50h", "Set PSP", "compat", "Updates the current PSP segment for runtimes that temporarily switch DOS process context."],
      ["51h", "Get PSP", "supported", "Alias for AH=62h; returns the current PSP segment in BX."],
      ["52h", "List of lists", "compat", "Returns a minimal internal DOS data pointer."],
      ["54h", "Get verify flag", "compat", "Returns the stored verify flag."],
      ["5Dh", "DOS internal", "stub", "Supports AX=5D06h with a minimal swappable-data-area pointer; other subfunctions fail."],
      ["60h", "Truename", "compat", "Canonicalizes 8.3 paths with drive, current directory, dot, and dot-dot handling."],
      ["63h", "Get DBCS table", "compat", "Returns an empty DBCS lead-byte table for single-byte code page setups."],
      ["66h", "Global code page", "compat", "Reports and accepts the default 437 code page used by Norton Commander-style startup probes."],
      ["71h", "Windows LFN family", "compat", "Always fails with AX=7100h so callers can detect unsupported long filename services and fall back."],
    ],
  },
  {
    title: "Directories, files, and save-game writes",
    rows: [
      ["39h", "Make directory", "supported", "Creates a FAT directory with initialized dot entries."],
      ["3Ah", "Remove directory", "supported", "Removes empty directories, refusing current/non-directory targets."],
      ["3Bh", "Change directory", "supported", "Handles root, `..`, subdirectories, and drive-qualified paths."],
      ["3Ch", "Create/truncate file", "supported", "Creates a new handle or truncates an existing writable closed file."],
      ["3Dh", "Open file", "supported", "Opens files and DOS device names using the requested access mode."],
      ["3Eh", "Close file", "supported", "Closes handles and flushes table metadata where needed."],
      ["3Fh", "Read file/device", "supported", "Reads through a sector cache and advances file position."],
      ["40h", "Write file/device", "supported", "Extends files, allocates clusters, updates size, and invalidates read cache."],
      ["41h", "Delete file", "supported", "Rejects directories, read-only files, and open files before freeing clusters."],
      ["42h", "Seek", "supported", "Supports DOS seek origins and 32-bit positions."],
      ["43h", "Get/set attributes", "supported", "Mutable bits can be changed; directory/volume identity is protected."],
      ["56h", "Rename", "supported", "Same-directory rename with read-only/open-handle guards."],
      ["57h", "Get/set file time", "supported", "Reads or writes directory timestamp fields for an open handle."],
      ["5Ah", "Create temporary file", "supported", "Generates `LDxxxx.TMP` style names under the requested path."],
      ["5Bh", "Create new file", "supported", "Fails if the target already exists."],
      ["68h", "Commit file", "supported", "Flushes handle directory entry and FAT for file handles."],
    ],
  },
  {
    title: "Handles, devices, processes, and memory",
    rows: [
      ["44h", "IOCTL", "partial", "Supports device info probes, input/output status, removable/local drive, and local handle checks."],
      ["45h", "Duplicate handle", "supported", "Creates aliases for table handles or implicit console std handles."],
      ["46h", "Force duplicate handle", "supported", "Replaces the destination handle with an alias/source device mapping."],
      ["48h", "Allocate memory", "supported", "Allocates paragraphs from the MCB arena."],
      ["49h", "Free memory", "supported", "Releases an MCB-owned block."],
      ["4Ah", "Resize memory", "supported", "Shrinks or grows blocks when adjacent free space permits."],
      ["4Bh", "EXEC", "partial", "Supports AL=00h load-and-run, AL=03h overlay load, child-owned environment copies with executable path tails, and inherited child PSP JFT entries."],
      ["4Ch", "Terminate with return code", "supported", "Stores AL and returns control to the parent or shell."],
      ["4Dh", "Get return code", "supported", "Returns and clears the last child return code and termination type."],
      ["58h", "Allocation strategy", "supported", "Supports get/set for first, best, and last fit."],
      ["62h", "Get PSP", "supported", "Returns the current PSP segment in BX."],
      ["67h", "Set handle count", "stub", "Refreshes fixed PSP JFT metadata; LainDOS still uses MAX_HANDLES=20."],
    ],
  },
  {
    title: "Directory search",
    rows: [
      ["11h", "FCB FindFirst", "narrow", "Searches the current directory from a normal or extended FCB, honoring the extended attribute mask, and writes AL status plus a drive byte/raw directory entry into the DTA."],
      ["12h", "FCB FindNext", "narrow", "Continues the saved current-directory FCB search state; richer FCB file APIs remain deferred."],
      ["47h", "Get current directory", "supported", "Returns the current directory path without the drive prefix."],
      ["4Eh", "FindFirst", "supported", "Stores search state in the DTA and returns the first matching entry."],
      ["4Fh", "FindNext", "supported", "Continues the DTA-backed directory search."],
    ],
  },
];

const DOSAPI_SUBFUNCTIONS = [
  ["AH=33h", "Ctrl-Break", "AL=00h gets the stored break flag, AL=01h sets it, AL=05h returns the boot drive, and AL=06h returns the true DOS version. Other subfunctions fail with function-number error."],
  ["AH=38h", "Country", "AL=00h/01h read the small default table; AL=FFh accepts country BX=1. Full international formatting tables are intentionally deferred."],
  ["AH=63h", "DBCS", "AL=00h returns DS:SI pointing at an empty lead-byte table; other subfunctions fail with function-number error."],
  ["AH=66h", "Code page", "AL=01h returns active/system code page 437; AL=02h accepts setting active code page BX=437. Other subfunctions fail with function-number error."],
  ["AH=5Dh", "DOS internal", "AX=5D06h returns DS:SI for a minimal swappable-data-area header with current DTA, PSP, return code/type, and drive fields; other subfunctions fail."],
  ["AH=71h", "LFN unsupported", "All Windows long-filename subfunctions fail with CF set and AX=7100h, matching the fallback signal expected by DJGPP-era callers."],
  ["AH=44h", "IOCTL", "AL=00h reads device information, AL=01h is accepted as the same compatibility answer, AL=06h/07h report input/output status, and AL=08h/09h/0Ah report local drive or handle state."],
  ["AH=4Bh", "EXEC", "AL=00h loads and runs a child program; AL=03h loads an overlay. Load-but-do-not-execute and other EXEC variants are not implemented yet."],
  ["AH=58h", "Allocator", "AL=00h gets the strategy and AL=01h sets strategy BL=0/1/2 for first/best/last fit. Other values fail with function-number error."],
];

function DosApiPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Compatibility surface
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            The DOS API
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 720, margin: 0 }}>
            <window.InlineText text={"`INT 21h` is what DOS programs call when they need the operating system: files, directories, memory, launching children, device checks, and compatibility probes. This page is the end-user map of what LainDOS can answer today."} />
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={{ border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 }}>
              <h2 style={dosH2(T)}>How to read this</h2>
              <p style={dosP(T)}>
                If a DOS game starts, opens its data files, launches overlays, saves, and exits back to the shell,
                it is mostly living on this page. BIOS calls still handle hardware like keyboard, video, disk sectors,
                <window.InlineText text={" timers, and sound devices; `INT 21h` is the DOS contract layered above that hardware."} />
              </p>
              <div className="dosapi-stat-grid" style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 10, marginTop: 14 }}>
                <MiniStat k="Target" v="games + utilities" />
                <MiniStat k="Version" v="DOS 3.30 identity" />
                <MiniStat k="Calls" v="68 AH branches" />
              </div>
            </section>

            <section style={{ border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 }}>
              <h2 style={dosH2(T)}>All recognized calls</h2>
              <p style={dosP(T)}>
                <window.InlineText text={"This is every `AH` value the current `INT 21h` dispatcher recognizes. `Supported` means the behavior is backed by real state or disk data in LainDOS. `Partial`, `narrow`, `compat`, and `stub` mean the call exists for the compatibility surface games and tests currently need, but it should not be read as full MS-DOS coverage."} />
              </p>
              <div style={{ display: "grid", gap: 16, marginTop: 16 }}>
                {DOSAPI_CALLS.map(block => <DosApiCallBlock key={block.title} block={block} />)}
              </div>
            </section>

            <section style={{ border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 }}>
              <h2 style={dosH2(T)}>Subfunction boundaries</h2>
              <p style={dosP(T)}>
                <window.InlineText text={"A recognized `AH` value does not always mean every `AL` subfunction exists. These are the narrow edges users are most likely to notice when a program probes DOS behavior."} />
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {DOSAPI_SUBFUNCTIONS.map(row => <DosApiSubfunction key={row[0]} row={row} />)}
              </div>
            </section>

            {DOSAPI_GROUPS.map(group => <DosApiGroup key={group.id} group={group} />)}

            <section style={{ border: `1px solid ${T.amber}`, borderRadius: 12, background: "#fff7e8", padding: "18px 20px", marginTop: 24 }}>
              <h2 style={dosH2(T)}>What is intentionally not complete</h2>
              <p style={dosP(T)}>
                LainDOS is not trying to be a replacement for every DOS installation. It grows from target programs
                and regression tests, so unsupported APIs are treated as new compatibility work rather than hidden magic.
              </p>
              <div style={{ display: "grid", gap: 9, marginTop: 12 }}>
                {DOSAPI_DEFERRED.map((item, i) => (
                  <div key={i} style={{ display: "flex", gap: 10, alignItems: "flex-start", color: T.dim,
                    fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 14.5, lineHeight: 1.55 }}>
                    <span style={{ color: T.amber, fontFamily: "'IBM Plex Mono', monospace" }}>todo</span><window.InlineText text={item} />
                  </div>
                ))}
              </div>
              <button onClick={() => go("run")} style={{ ...dosButton(T.pink), marginTop: 16 }}>Boot it and try commands</button>
            </section>
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={{ border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, overflow: "hidden" }}>
              <div style={{ padding: "11px 14px", borderBottom: `1px solid ${T.line}`, fontFamily: "'IBM Plex Mono', monospace",
                fontSize: 11.5, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim }}>
                User checklist
              </div>
              {[
                ["Boots to shell", "SHELL.COM reached A:\\> via EXEC-ready DOS services."],
                ["Runs demo", "MIDEMO.EXE opens data, switches video, and plays."],
                ["Can save", "Writable FAT paths handle create/write/flush/delete/rename."],
                ["Useful failure", "Unsupported calls should show in serial logs."],
              ].map((row, i) => (
                <div key={row[0]} style={{ padding: "12px 14px", borderBottom: i < 3 ? `1px solid ${T.line}` : "none" }}>
                  <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.amber }}>{row[0]}</div>
                  <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13, color: T.dim, lineHeight: 1.45, marginTop: 3 }}>{row[1]}</div>
                </div>
              ))}
            </div>
            <div style={{ marginTop: 14, border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" }}>
              <h3 style={dosKicker(T)}>Common next reads</h3>
              <button onClick={() => go("boot/s4")} style={{ ...dosButton(T.amber), width: "100%", marginBottom: 8 }}>How INT 21h is installed</button>
              <button onClick={() => go("run")} style={{ ...dosButton(T.pink), width: "100%" }}>Run the live image</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function DosApiGroup({ group }) {
  const T = window.T;
  return (
    <section id={group.id} style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8, flexWrap: "wrap" }}>
        <h2 style={{ ...dosH2(T), margin: 0 }}>{group.title}</h2>
        <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: T.green, border: `1px solid ${T.line}`,
          borderRadius: 20, padding: "3px 8px", background: T.panel }}>covered</span>
      </div>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.amber, marginBottom: 10 }}>{group.calls}</div>
      <p style={{ ...dosP(T), color: T.ink, fontWeight: 600 }}>{group.verdict}</p>
      {group.prose.map((p, i) => <p key={i} style={dosP(T)}><window.InlineText text={p} /></p>)}
      <div style={{ display: "grid", gap: 14, marginTop: 16, alignItems: "start" }}>
        <window.CodeBlock file={group.codeFile} code={group.code} hi={group.code.filter(l => typeof l[0] === "number").map(l => l[0])} />
        <div style={{ display: "grid", gap: 12 }}>
          <window.RegPanel regs={group.regs} />
          <div style={{ border: `1px solid ${T.line}`, borderRadius: 9, background: T.panel, padding: "10px 12px" }}>
            <h3 style={dosKicker(T)}>Regression coverage</h3>
            <div style={{ display: "grid", gap: 6 }}>
              {group.tests.map(test => <code key={test} style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue }}>{test}</code>)}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function DosApiCallBlock({ block }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 10, overflow: "hidden", background: "#fffdf6" }}>
      <div style={{ padding: "10px 12px", borderBottom: `1px solid ${T.line}`, fontFamily: "'IBM Plex Mono', monospace",
        fontSize: 12, color: T.amber, letterSpacing: 1, textTransform: "uppercase" }}>{block.title}</div>
      <div style={{ display: "grid" }}>
        {block.rows.map((row, i) => <DosApiCallRow key={`${block.title}-${row[0]}`} row={row} last={i === block.rows.length - 1} />)}
      </div>
    </div>
  );
}

function DosApiCallRow({ row, last }) {
  const T = window.T;
  const color = row[2] === "supported" ? T.green : row[2] === "partial" ? T.amber : T.faint;
  return (
    <div className="dosapi-call-row" style={{ display: "grid", gridTemplateColumns: "50px 170px 86px 1fr", gap: 10, alignItems: "baseline",
      padding: "8px 12px", borderBottom: last ? "none" : `1px solid ${T.line}` }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.pink }}>{row[0]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.ink, fontWeight: 600 }}><window.InlineText text={row[1]} /></div>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color, textTransform: "uppercase" }}>{row[2]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13, color: T.dim, lineHeight: 1.45 }}><window.InlineText text={row[3]} /></div>
    </div>
  );
}

function DosApiSubfunction({ row }) {
  const T = window.T;
  return (
    <div className="dosapi-sub-row" style={{ display: "grid", gridTemplateColumns: "72px 110px 1fr", gap: 12, alignItems: "baseline",
      border: `1px solid ${T.line}`, borderRadius: 9, background: "#fffdf6", padding: "10px 12px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.pink }}>{row[0]}</code>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber, textTransform: "uppercase" }}>{row[1]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.5 }}><window.InlineText text={row[2]} /></div>
    </div>
  );
}

function MiniStat({ k, v }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "9px 11px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: T.faint, textTransform: "uppercase", letterSpacing: 1 }}>{k}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 14, color: T.ink, marginTop: 2 }}>{v}</div>
    </div>
  );
}

function dosH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function dosP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, maxWidth: 720, margin: "0 0 12px" };
}
function dosKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function dosButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer" };
}

Object.assign(window, { DosApiPage });
