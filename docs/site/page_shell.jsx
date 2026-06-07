// page_shell.jsx - shell, batch startup, environment, and PATH behavior.

const SHELL_FLOW = [
  ["Startup", "The kernel boots SHELL.COM as the first program, then the shell shrinks its PSP block and prints the banner."],
  ["AUTOEXEC", "If AUTOEXEC.BAT exists in the root, it runs before the first interactive prompt."],
  ["Prompt", "The prompt is built from the current drive plus AH=47h current-directory state."],
  ["Dispatch", "A line is uppercased, checked for built-ins or drive switches, then treated as COM, EXE, or BAT."],
  ["Return", "Child programs return through AH=4Dh so the shell can recover state and print the next prompt."],
];

const SHELL_COMMANDS = [
  ["EXIT", "Terminate the shell with AH=4Ch."],
  ["VER", "Print the LainDOS version banner."],
  ["DIR [path|pattern] [/P] [/W]", "List a directory or wildcard pattern; /P pauses after each screenful and /W uses a compact wide layout."],
  ["CD/CHDIR [path]", "Change directory, print the current directory with no path, and accept compact CD.. and CD\\ forms."],
  ["MD/MKDIR path", "Create a directory."],
  ["RD/RMDIR path", "Remove an empty directory."],
  ["COPY [/Y|/-Y] source destination", "Copy one file, including into an existing destination directory, and prompt before overwriting unless /Y is present."],
  ["DEL/ERASE [/P] file", "Delete one file path, optionally prompting first with /P."],
  ["REN/RENAME source name", "Rename one file; the destination must be a filename, not a drive or path."],
  ["TYPE file", "Stream a file to standard output."],
  ["CLS", "Emit form feed to clear the screen."],
  ["ECHO text", "Print text; ECHO ON/OFF are accepted as quiet no-ops."],
  ["REM text", "Ignore a comment line in batch or interactive input."],
  ["A: / B: / C:", "Switch the current default drive when that drive exists."],
  ["name [args]", "Run .COM, .EXE, or .BAT from the current directory or PATH."],
];

const SHELL_EXAMPLES = [
  ["DIR /P", "Page through the boot floppy. The live page image includes SHELL.COM, KERNEL.SYS, and the Monkey Island demo files."],
  ["TYPE README", "Read the bundled Monkey Island demo readme from the live floppy."],
  ["TYPE MONKEY.TXT", "Print the demo's text notes without leaving the shell."],
  ["MIDEMO", "Launch the Monkey Island demo through EXEC, then return to the shell when it exits."],
  ["VER", "Confirm the command is handled as a built-in rather than an external program."],
  ["C:", "With a local QEMU run that attaches a hard disk, switch from A: to C:."],
];

const SHELL_UNSUPPORTED = [
  "No full COMMAND.COM compatibility: no SET command, prompt expansion, user-defined aliases, pipes, redirection, or wildcard argument expansion.",
  "Batch files are straight-line scripts. There is no CALL, GOTO, IF, FOR, labels, variable expansion, or nested batch execution.",
  "AUTOEXEC.BAT is the only startup script. CONFIG.SYS and installable DOS device drivers remain out of scope.",
  "Bad commands print an error and batch execution continues; this matches the current game/test needs rather than full DOS policy.",
];

const SHELL_TESTS = [
  ["Interactive shell", "scripts/test_shell.py", "Drives VER, CLS, DIR path/pattern, DIR /P, DIR /W, COPY, DEL/ERASE, REN/RENAME, TYPE, ECHO, REM, COM/EXE/BAT launch, directories, and error paths."],
  ["AUTOEXEC", "scripts/test_autoexec.py", "Builds images with and without AUTOEXEC.BAT and proves startup batch continues after a bad command."],
  ["Environment/PATH", "scripts/test_envpath.py", "Checks COMSPEC, PATH, PROMPT, BLASTER, and PATH launch from a different current directory."],
  ["Env block", "tests/programs/envtest.asm", "Reads PSP:2Ch and validates default variables plus the executable path tail."],
  ["Multi-drive shell", "scripts/test_multidrive_shell.py", "Boots from A: with an attached C: disk and switches drives at the prompt."],
  ["Monkey smoke", "scripts/test_shell_monkey.py", "Launches MIDEMO from the shell and checks for a live framebuffer."],
];

const SHELL_SECTIONS = [
  {
    id: "loop",
    title: "Startup and dispatch",
    summary: "SHELL.COM owns the prompt loop after boot.",
    body: [
      "The kernel boots SHELL.COM like any other COM program. The shell immediately shrinks its allocation with AH=4Ah, prints `LainDOS Shell`, tries AUTOEXEC.BAT, and then enters the prompt loop.",
      "Every interactive line is read with AH=0Ah, uppercased in-place, checked for a standalone drive switch, matched against the built-in command table, and finally passed to external command lookup.",
    ],
    file: "programs/shell.asm",
    code: [
      [16, "    mov bx, shell_resident_paras"],
      [17, "    mov ah, 0x4A"],
      [18, "    int 0x21"],
      [25, "    call run_autoexec"],
      ["", "; ..."],
      [27, "prompt:"],
      [28, "    call print_prompt"],
      [29, "    call read_line"],
      [30, "    call uppercase_line"],
      [31, "    call execute_line"],
      [32, "    jmp prompt"],
      ["", "; ..."],
      [41, "    call change_drive_command"],
      [43, "    mov bx, command_table"],
      [55, ".external:"],
      [56, "    call prepare_command"],
      [57, "    call run_command"],
    ],
    hi: [25, 27, 41, 56, 57],
    tests: ["scripts/test_shell.py", "scripts/test_autoexec.py"],
  },
  {
    id: "commands",
    title: "Built-ins and current directory",
    summary: "Built-ins are small DOS API wrappers.",
    body: [
      "The built-ins intentionally stay narrow. `DIR` builds a FindFirst/FindNext pattern from the optional operand, formats entries like MS-DOS with fixed 8.3 columns or `/W` columns, and supports `/P` pagination. `CD`, `MD`, `RD`, and their DOS aliases call the matching directory APIs. `COPY` implements the single-file binary subset with overwrite confirmation, `DEL` and `ERASE` delete one file with optional `/P`, `REN` and `RENAME` rename one file without moving it, and `TYPE` opens a file and copies it to handle 1.",
      "The prompt and drive switches are DOS state, not private shell variables. The prompt asks AH=19h for the current drive and AH=47h for the current directory; `C:` uses AH=0Eh to select the drive and relies on the kernel to reject missing drives.",
    ],
    file: "programs/shell.asm",
    code: [
      [78, "do_dir:"],
      [79, "    call parse_dir_args"],
      [89, "    call print_dir_header"],
      [93, "    mov dx, dir_pattern"],
      [94, "    mov cx, ATTR_DIR"],
      [95, "    mov ah, 0x4E"],
      [101, "    call print_dir_entry"],
      [104, "    call print_dir_wide_entry"],
      [110, "    call finish_dir_wide_row"],
      [111, "    call print_dir_summary"],
      [865, "do_copy:"],
      [866, "    call parse_copy_args"],
      [873, "    mov ah, 0x3D"],
      [881, "    mov ah, 0x3C"],
      [889, "    mov ah, 0x3F"],
      [898, "    mov ah, 0x40"],
      [911, "    mov dx, copy_success_msg"],
      [1150, "do_cd:"],
      [1153, "    mov dx, si"],
      [1154, "    mov ah, 0x3B"],
      ["", "; ..."],
      [1226, "do_del:"],
      [1230, "    call del_path_has_wildcard"],
      [1235, "    mov ah, 0x41"],
      [1292, "confirm_del_prompt:"],
      [1301, "    mov ah, 0x08"],
      [1317, "del_path_has_wildcard:"],
      [1326, "    cmp al, '*'"],
      ["", "; ..."],
      [1338, "do_ren:"],
      [1343, "    call ren_paths_have_wildcard"],
      [1345, "    call ren_dst_has_path"],
      [1351, "    mov ah, 0x56"],
      [1413, "ren_dst_has_path:"],
      [1419, "    cmp al, ':'"],
      ["", "; ..."],
      [1512, "change_drive_command:"],
      [1534, "    mov dl, al"],
      [1536, "    mov ah, 0x0E"],
      [1556, "print_prompt:"],
      [1560, "    mov ah, 0x47"],
      [1568, "    mov dx, prompt_end"],
      ["", "; ..."],
      [2201, "command_table:"],
      [2202, "    dw exit_cmd, exit_shell"],
      [2204, "    dw dir_cmd, do_dir"],
      [2205, "    dw cd_cmd, do_cd"],
      [2206, "    dw cd_parent_cmd, do_cd_parent"],
      [2207, "    dw cd_root_cmd, do_cd_root"],
      [2208, "    dw chdir_cmd, do_cd"],
      [2209, "    dw md_cmd, do_md"],
      [2210, "    dw mkdir_cmd, do_md"],
      [2211, "    dw rd_cmd, do_rd"],
      [2212, "    dw rmdir_cmd, do_rd"],
      [2213, "    dw copy_cmd, do_copy"],
      [2214, "    dw del_cmd, do_del"],
      [2215, "    dw erase_cmd, do_del"],
      [2216, "    dw ren_cmd, do_ren"],
      [2217, "    dw rename_cmd, do_ren"],
      [2218, "    dw type_cmd, do_type"],
      [2220, "    dw echo_cmd, do_echo"],
      [2221, "    dw rem_cmd, do_rem"],
    ],
    hi: [78, 95, 101, 104, 110, 111, 865, 873, 881, 889, 898, 911, 1226, 1230, 1235, 1292, 1317, 1338, 1343, 1345, 1351, 1413, 1512, 1536, 1556, 1560, 2201, 2206, 2208, 2210, 2212, 2213, 2214, 2215, 2216, 2217],
    tests: ["scripts/test_shell.py", "scripts/test_multidrive_shell.py"],
  },
  {
    id: "exec",
    title: "External command lookup",
    summary: "COM, EXE, and BAT are tried locally before PATH.",
    body: [
      "If the command has no extension, the shell first tries `.COM`, then `.EXE`, then `.BAT` in the current directory. Only after those fail does it walk PATH for COM, EXE, and BAT candidates.",
      "Arguments are copied to a PSP-compatible command tail. Successful child programs return through AH=4Dh so the shell consumes the exit status and restores DS before printing the next prompt.",
    ],
    file: "programs/shell.asm",
    code: [
      [1617, "prepare_command:"],
      [1620, "    mov byte [command_has_ext], 0"],
      [1658, "    cmp byte [command_has_ext], 0"],
      [1660, "    mov al, '.'"],
      [1663, "    mov al, 'C'"],
      [1665, "    mov al, 'O'"],
      [1667, "    mov al, 'M'"],
      [1672, "    call build_cmd_tail"],
      ["", "; ..."],
      [1704, "run_command:"],
      [1707, "    call run_current_command"],
      [1715, "    call run_current_command"],
      [1723, "    call run_batch"],
      [1729, "    call run_path_exec"],
      [1741, "    call run_path_batch"],
      [1764, "    mov ah, 0x4D"],
      [1765, "    int 0x21"],
      [1796, "run_current_command:"],
      [1811, "    mov ax, 0x4B00"],
      [1812, "    int 0x21"],
    ],
    hi: [1617, 1672, 1704, 1707, 1723, 1729, 1741, 1764, 1811],
    tests: ["scripts/test_shell.py", "scripts/test_execparam.py", "scripts/test_spawn.py"],
  },
  {
    id: "batch",
    title: "AUTOEXEC.BAT and batch lines",
    summary: "Startup batch is a simple straight-line script.",
    body: [
      "`run_autoexec` just asks the batch runner to open `AUTOEXEC.BAT`. Missing files are ignored, which gives the same shell prompt on images without startup scripts.",
      "Batch files are read into a fixed 512-byte buffer, split on CR/LF, uppercased, and executed through the same command path as interactive input. Empty lines are skipped; errors do not abort the script; nested batch files are rejected by `batch_active`.",
    ],
    file: "programs/shell.asm",
    code: [
      [1821, "run_autoexec:"],
      [1824, "    mov dx, autoexec_name"],
      [1825, "    call run_batch_named"],
      ["", "; ..."],
      [1836, "run_batch_named:"],
      [1837, "    cmp byte [batch_active], 0"],
      [1839, "    mov byte [batch_active], 1"],
      [1841, "    mov ah, 0x3D"],
      [1850, "    mov ah, 0x3F"],
      [1862, "    mov si, batch_buf"],
      [1864, "    call batch_read_line"],
      [1870, "    call execute_line"],
      [1876, "    mov byte [batch_active], 0"],
      ["", "; ..."],
      [2067, "batch_read_line:"],
      [2089, "    cmp cx, 63"],
      [2091, "    stosb"],
      [2099, ".eof:"],
      [2100, "    stc"],
    ],
    hi: [1821, 1825, 1836, 1837, 1864, 1870, 2067, 2089],
    tests: ["scripts/test_autoexec.py", "scripts/test_shell.py"],
  },
  {
    id: "path",
    title: "PATH lookup",
    summary: "The shell reads PATH from its PSP environment.",
    body: [
      "PATH lookup is deliberately caller-visible. The shell asks AH=62h for its PSP, follows PSP:2Ch to the environment block, finds the `PATH=` string, and tries each semicolon-separated directory.",
      "Commands that already contain a drive or slash bypass PATH. This keeps explicit paths deterministic while still allowing `PATHRUN` from `A:\BIN` after the user changes into another directory.",
    ],
    file: "programs/shell.asm",
    code: [
      [1889, "run_path_exec:"],
      [1893, "run_path_batch:"],
      [1896, "run_path_command:"],
      [1897, "    cmp byte [command_has_path], 0"],
      [1899, "    call find_path_value"],
      [1902, "    call build_path_candidate"],
      [1906, "    call run_candidate_exec"],
      [1909, "    call run_batch_path"],
      ["", "; ..."],
      [1929, "find_path_value:"],
      [1936, "    mov ah, 0x62"],
      [1942, "    mov ax, [es:0x2C]"],
      [1950, "    mov si, path_env_name"],
      [1970, ".found:"],
      [1972, "    mov [path_env_seg], ax"],
      ["", "; ..."],
      [1992, "build_path_candidate:"],
      [2012, "    cmp al, ';'"],
      [2039, "    mov al, '\\'"],
      [2046, "    mov si, command_name"],
      [2054, "    clc"],
    ],
    hi: [1896, 1897, 1899, 1902, 1936, 1942, 1950, 1992, 2012, 2039],
    tests: ["scripts/test_envpath.py", "tests/programs/pathrun.asm"],
  },
  {
    id: "environment",
    title: "Default environment",
    summary: "COMSPEC, PATH, PROMPT, and BLASTER are kernel-provided.",
    body: [
      "The boot program gets an MCB-backed environment before it starts. Default variables include `COMSPEC=A:\SHELL.COM`, `PATH=A:\;A:\BIN`, `PROMPT=$P$G`, and the conventional Sound Blaster string used by game setup tools.",
      "When the shell EXECs a child, the loader copies or writes an environment and appends the DOS executable-path tail. The environment tests read PSP:2Ch and verify both the variables and the tail visible to child programs.",
    ],
    file: "src/kernel.asm",
    code: [
      [1325, "init_environment:"],
      [1332, "    call alloc_exec_environment"],
      [1339, "    call write_environment_vars"],
      [1340, "    mov ax, 1"],
      [1341, "    stosw"],
      [1348, "    mov si, fname_exe"],
      ["", "; ..."],
      [1382, "write_environment_vars:"],
      [1388, "    mov si, env_comspec_name"],
      [1393, "    mov si, env_path_name"],
      [1401, "    mov si, env_blaster"],
      [1403, "    mov si, env_prompt"],
      [1405, "    xor al, al"],
      [1428, "env_copy_drive_root:"],
      [1429, "    mov al, [cs:dos_drive_letter]"],
      ["", "; ..."],
      [2776, "env_comspec_name: db \"COMSPEC=\", 0"],
      [2777, "env_path_name: db \"PATH=\", 0"],
      [2778, "env_shell_name: db \"SHELL.COM\", 0"],
      [2779, "env_bin_dir: db \"BIN\", 0"],
      [2780, "env_blaster: db \"BLASTER=A220 I5 D1 H5 P330 T6\", 0"],
      [2781, "env_prompt: db \"PROMPT=$P$G\", 0"],
    ],
    hi: [1314, 1321, 1328, 1371, 1377, 1382, 1390, 1392, 2765, 2766],
    tests: ["scripts/test_envpath.py", "scripts/test_execenv.py", "tests/programs/envtest.asm"],
  },
];

function ShellDocsPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Shell track
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Shell
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 790, margin: 0 }}>
            How the LainDOS prompt works after boot: built-ins, current directories, AUTOEXEC.BAT,
            PATH search, environment variables, and the small boundary where it intentionally stops
            short of COMMAND.COM compatibility.
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={shellCard(T)}>
              <h2 style={shellH2(T)}>From boot to A:\&gt;</h2>
              <p style={shellP(T)}>
                The shell is just another DOS program, but it is the user-facing control loop for the live image.
                It receives the initial PSP and environment, runs optional startup commands, then keeps handing
                <window.InlineText text={" child programs to EXEC until `EXIT` terminates it."} />
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {SHELL_FLOW.map((row, i) => <ShellFlow key={row[0]} row={row} index={i} />)}
              </div>
            </section>

            {SHELL_SECTIONS.map(section => <ShellSection key={section.id} section={section} />)}

            <section id="unsupported" style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
              <h2 style={shellH2(T)}>What this is not</h2>
              <p style={shellP(T)}>
                LainDOS keeps shell behavior target-driven. The current shell is enough for test images,
                startup scripts, PATH-based game launchers, and manual emulator use, but it is not a full
                clone of COMMAND.COM.
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {SHELL_UNSUPPORTED.map(item => <ShellUnsupported key={item} text={item} />)}
              </div>
            </section>
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={shellPanel(T)}>
              <h3 style={shellKicker(T)}>Try in the emulator</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {SHELL_EXAMPLES.map(row => <ShellExample key={row[0]} row={row} />)}
              </div>
              <button onClick={() => go("run")} style={{ ...shellButton(T.pink), marginTop: 12 }}>Open the live machine</button>
            </div>
            <div style={{ ...shellPanel(T), marginTop: 14 }}>
              <h3 style={shellKicker(T)}>Supported command surface</h3>
              <div style={{ display: "grid", gap: 7 }}>
                {SHELL_COMMANDS.map(row => <ShellCommand key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...shellPanel(T), marginTop: 14 }}>
              <h3 style={shellKicker(T)}>Regression map</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {SHELL_TESTS.map(row => <ShellTest key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...shellPanel(T), marginTop: 14 }}>
              <h3 style={shellKicker(T)}>Related tracks</h3>
              <button onClick={() => go("prog")} style={{ ...shellButton(T.amber), marginBottom: 8 }}>Program loading</button>
              <button onClick={() => go("fs")} style={{ ...shellButton(T.blue), marginBottom: 8 }}>Filesystem</button>
              <button onClick={() => go("tests")} style={shellButton(T.green)}>Test ladder</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function ShellFlow({ row, index }) {
  const T = window.T;
  return (
    <div style={{ display: "grid", gridTemplateColumns: "42px 116px 1fr", gap: 12, alignItems: "baseline",
      border: `1px solid ${T.line}`, borderRadius: 10, background: "#fffdf6", padding: "10px 12px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.faint }}>{String(index + 1).padStart(2, "0")}</code>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.amber, textTransform: "uppercase" }}>{row[0]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.5 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function ShellSection({ section }) {
  const T = window.T;
  return (
    <section id={section.id} style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap", marginBottom: 8 }}>
        <h2 style={{ ...shellH2(T), margin: 0 }}>{section.title}</h2>
        <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber }}>{section.summary}</code>
      </div>
      {section.body.map((p, i) => <p key={i} style={shellP(T)}><window.InlineText text={p} /></p>)}
      <div style={{ display: "grid", gap: 14, marginTop: 16, alignItems: "start" }}>
        <window.CodeBlock file={section.file} code={section.code} hi={section.hi} />
        <div style={shellPanel(T)}>
          <h3 style={shellKicker(T)}>Tests that pin this</h3>
          <div style={{ display: "grid", gap: 7 }}>
            {section.tests.map(test => <ShellTestLink key={test} path={test} />)}
          </div>
        </div>
      </div>
    </section>
  );
}

function ShellExample({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.pink }}>{row[0]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function ShellCommand({ row }) {
  const T = window.T;
  return (
    <div style={{ display: "grid", gap: 3, borderTop: `1px solid ${T.line}`, padding: "9px 0" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber }}>{row[0]}</code>
      <span style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.3, color: T.dim, lineHeight: 1.45 }}><window.InlineText text={row[1]} /></span>
    </div>
  );
}

function ShellTest({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber, textTransform: "uppercase" }}>{row[0]}</div>
      <ShellTestLink path={row[1]} />
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[2]} /></div>
    </div>
  );
}

function ShellTestLink({ path }) {
  const T = window.T;
  return (
    <a href={`https://github.com/lambadalambda/laindos/blob/main/${path}`} target="_blank" rel="noreferrer"
      style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue, textDecoration: "none" }}>
      {path}
    </a>
  );
}

function ShellUnsupported({ text }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 9, background: "#fffdf6", padding: "11px 13px",
      fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.55 }}>
      <window.InlineText text={text} />
    </div>
  );
}

function shellCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function shellPanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function shellH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function shellP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, maxWidth: 760, margin: "0 0 12px" };
}
function shellKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function shellButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { ShellDocsPage });
