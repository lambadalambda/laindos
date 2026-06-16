// page_shell.jsx - shell, batch startup, environment, and PATH behavior.

const SHELL_FLOW = [
  ["Startup", "The kernel boots SHELL.COM as the first program, then the shell shrinks its PSP block and prints the banner."],
  ["AUTOEXEC", "If AUTOEXEC.BAT exists in the root, it runs before the first interactive prompt."],
  ["Prompt", "The prompt is built from the current drive plus AH=47h current-directory state."],
  ["Dispatch", "A line is matched case-insensitively against built-ins or drive switches, then treated as COM, EXE, or BAT."],
  ["Return", "Child programs return through AH=4Dh so the shell can recover state and print the next prompt."],
];

const SHELL_COMMANDS = [
  ["EXIT", "Terminate the shell with AH=4Ch."],
  ["VER", "Print the LainDOS version banner."],
  ["DIR [path|pattern] [/P] [/W]", "List a directory or wildcard pattern with raw byte counts plus human-readable used/free totals; /P pauses after each screenful and /W uses a compact wide layout."],
  ["CD/CHDIR [path]", "Change directory, print the current directory with no path, and accept compact CD.. and CD\\ forms."],
  ["MD/MKDIR path", "Create a directory."],
  ["RD/RMDIR path", "Remove an empty directory; non-empty directories report a directory/access error instead of a missing path."],
  ["DELTREE [/Y] path", "Recursively remove a directory tree, prompting unless /Y is supplied; root and current-directory references are refused."],
  ["COPY [/Y|/-Y] source [destination]", "Copy a file or wildcard pattern, into the current or an existing destination directory, prompting before overwriting unless /Y is present."],
  ["DEL/ERASE [/P] file", "Delete one file path, optionally prompting first with /P."],
  ["REN/RENAME source name", "Rename one file; the destination must be a filename, not a drive or path."],
  ["TYPE file", "Stream a file to standard output."],
  ["CLS", "Emit form feed to clear the screen."],
  ["ECHO text", "Print text; ECHO ON/OFF are accepted as quiet no-ops."],
  ["REM text", "Ignore a comment line in batch or interactive input."],
  ["PAUSE [> nul]", "Print the DOS pause prompt and wait for a key, or return quietly when redirected to NUL."],
  ["BREAK ON|OFF", "Accept Ctrl-Break toggles as no-ops."],
  ["MODE CO80 [> nul]", "Switch to BIOS 80-column color text mode."],
  ["MORE < file [> nul]", "Page a redirected file in 24-line screens."],
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
  "No full COMMAND.COM compatibility: no SET command, prompt expansion, user-defined aliases, pipes, general redirection, or wildcard argument expansion.",
  "Batch control is deliberately narrow: labels, GOTO (a missing label prints `Label not found` and ends the batch), IF with NOT/EXIST/ERRORLEVEL/== forms, %1-%9 parameters, and nested BAT files are supported, but there is no CALL, FOR, environment-variable expansion, or pipes.",
  "AUTOEXEC.BAT is the only startup script. CONFIG.SYS and installable DOS device drivers remain out of scope.",
  "Bad commands print an error and batch execution continues; this matches the current game/test needs rather than full DOS policy.",
];

const SHELL_TESTS = [
  ["Interactive shell", "scripts/test_shell.py", "Drives VER, CLS, DIR path/pattern and human-readable summaries, DIR /P, DIR /W, COPY, DEL/ERASE, DELTREE success, confirmation, guards, REN/RENAME, TYPE, ECHO, REM, COM/EXE/BAT launch, directories, and error paths."],
  ["Batch builtins", "scripts/test_shell_batch_builtins.py", "Exercises PAUSE, BREAK, MODE CO80, MORE < file, NUL redirects, long batches, nested batches, IF EXIST, GOTO, labels, and case-preserved arguments."],
  ["AUTOEXEC", "scripts/test_autoexec.py", "Builds images with and without AUTOEXEC.BAT and proves startup batch continues after a bad command."],
  ["Environment/PATH", "scripts/test_envpath.py", "Checks COMSPEC, PATH, PROMPT, BLASTER, and PATH launch from a different current directory."],
  ["Env block", "tests/programs/envtest.asm", "Reads PSP:2Ch and validates default variables plus the executable path tail."],
  ["Multi-drive shell", "scripts/test_multidrive_shell.py", "Boots from A: with an attached C: disk and switches drives at the prompt."],
  ["Monkey smoke", "scripts/test_shell_monkey.py", "Launches MIDEMO from the shell and checks for a live framebuffer."],
  ["Redirection", "scripts/test_shellredir.py", "Echoes through >NUL, >file, and >>file from a batch and checks the console only sees what it should."],
];

const SHELL_SECTIONS = [
  {
    id: "loop",
    title: "Startup and dispatch",
    summary: "SHELL.COM owns the prompt loop after boot.",
    body: [
      "The kernel boots SHELL.COM like any other COM program. The shell immediately shrinks its allocation with AH=4Ah, prints `LainDOS Shell` plus the embedded build id, tries AUTOEXEC.BAT, and then enters the prompt loop.",
      "Every interactive line is read with AH=0Ah, checked for a standalone drive switch, matched case-insensitively against the built-in command table, and finally passed to external command lookup without uppercasing arguments. Tabs count as whitespace everywhere spaces do, so tab-indented batch lines parse normally.",
      "Before dispatch, redir_setup strips a trailing `>file` or `>>file` from the line, saves stdout with AH=45h, and force-duplicates the opened target onto handle 1 with AH=46h. All shell output goes through AH=40h writes to handle 1, so built-ins and spawned programs alike inherit the redirection; `>NUL` discards via the kernel NUL device. redir_restore puts the console back after the command.",
    ],
    file: "programs/shell.asm",
    code: [
      [23, "    mov bx, shell_resident_paras"],
      [24, "    mov ah, 0x4A"],
      [20, "    int 0x21"],
      [29, "    call run_command_tail"],
      [33, "    call run_autoexec"],
      ["", "; ..."],
      [35, "prompt:"],
      [36, "    call print_prompt"],
      [37, "    call read_line"],
      [38, "    call execute_line"],
      [39, "    jmp prompt"],
      ["", "; ..."],
      [41, "execute_line:"],
      [44, "    call redir_setup"],
      [48, "    mov si, line_buf"],
      [49, "    call skip_command_prefix"],
      [54, "    call change_drive_command"],
      [56, "    mov bx, command_table"],
      [62, "    call cmd_match"],
      [67, "    call [bx+2]"],
      [69, ".external:"],
      [70, "    call prepare_command"],
      [71, "    call run_command"],
      [76, "    call redir_restore"],
    ],
    hi: [29, 33, 39, 44, 48, 56, 70, 67, 76],
    tests: ["scripts/test_shell.py", "scripts/test_autoexec.py"],
  },
  {
    id: "commands",
    title: "Built-ins and current directory",
    summary: "Built-ins are small DOS API wrappers.",
    body: [
      "The built-ins intentionally stay narrow. `DIR` builds a FindFirst/FindNext pattern from the optional operand, formats entries like MS-DOS with fixed 8.3 columns or `/W` columns, appends human-readable used/free suffixes to the raw-byte summary, and supports `/P` pagination. `CD`, `MD`, `RD`, and their DOS aliases call the matching directory APIs; `RD` only removes empty directories, while `DELTREE [/Y] path` walks a directory tree bottom-up and removes files plus subdirectories, refusing root and current-directory references. `COPY` copies single files or wildcard patterns (FindFirst/FindNext expansion) with overwrite confirmation, defaulting the destination to the current directory, `DEL` and `ERASE` delete files or wildcard patterns with optional `/P`, `REN` and `RENAME` rename one file without moving it, and `TYPE` opens a file and copies it to handle 1.",
      "Startup-script conveniences are minimal: `PAUSE` prints `Press any key to continue . . .` and waits on INT 16h AH=0, `BREAK` is accepted as a no-op (LainDOS does not implement user-mode Ctrl-Break), `MODE CO80` issues INT 10h AH=00h AL=03h, and `MORE < file` reads the file in 4 KiB chunks, prints each line, and waits on the more prompt between screens. `PAUSE`, `MODE`, and `MORE` accept a trailing `> nul` (with or without space) and suppress the prompt; `MORE` accepts a leading `< file` (with space) to redirect input. Batch control includes labels, `GOTO`, `IF [NOT] EXIST path / ERRORLEVEL n / a==b command` (ERRORLEVEL compares the stored AH=4Dh exit code; unrecognized forms print `Syntax error`), and `%1`-`%9`/`%%` parameter expansion for the vendor scripts that need them.",
      "The prompt and drive switches are DOS state, not private shell variables. The prompt asks AH=19h for the current drive and AH=47h for the current directory; `C:` uses AH=0Eh to select the drive and relies on the kernel to reject missing drives.",
    ],
    file: "programs/shell.asm",
    code: [
      [242, "do_dir:"],
      [243, "    call parse_dir_args"],
      [253, "    call print_dir_header"],
      [257, "    mov dx, dir_pattern"],
      [258, "    mov cx, ATTR_DIR"],
      [259, "    mov ah, 0x4E"],
      [265, "    call print_dir_entry"],
      [268, "    call print_dir_wide_entry"],
      [274, "    call finish_dir_wide_row"],
      [275, "    call print_dir_summary"],
      [1194, "do_copy:"],
      [1195, "    call parse_copy_args"],
      [1217, "    mov ah, 0x4E"],
      [1243, "copy_one_file:"],
      [1264, "    mov ah, 0x3D"],
      [1272, "    mov ah, 0x3C"],
      [1280, "    mov ah, 0x3F"],
      [1289, "    mov ah, 0x40"],
      [1302, "    mov dx, copy_success_msg"],
      [1564, "do_cd:"],
      [1567, "    mov dx, si"],
      [1568, "    mov ah, 0x3B"],
      [1576, "    mov ah, 0x47"],
      ["", "; ..."],
      [1629, "do_del:"],
      [1633, "    call del_path_has_wildcard"],
      [1676, "    mov ah, 0x41"],
      [1727, "confirm_del_prompt:"],
      [1520, "    mov ah, 0x08"],
      [1737, "del_path_has_wildcard:"],
      [1746, "    cmp al, '*'"],
      ["", "; ..."],
      [1758, "do_ren:"],
      [1763, "    call ren_paths_have_wildcard"],
      [1765, "    call ren_dst_has_path"],
      [1771, "    mov ah, 0x56"],
      [1834, "ren_dst_has_path:"],
      [1840, "    cmp al, ':'"],
      ["", "; ..."],
      [1928, "do_goto:"],
      [1932, "    call batch_seek_label"],
      [1936, "do_if:"],
      [1952, "    mov di, exist_arg"],
      [1987, "    mov ax, 0x4300"],
      [2097, "    mov di, line_buf"],
      [2104, "    call execute_line"],
      [1932, "    call batch_seek_label"],
      [2113, "batch_seek_label:"],
      [2133, "    call batch_read_line"],
      [2141, "    call batch_label_match"],
      ["", "; ..."],
      [2242, "do_pause:"],
      [2246, "    mov dx, pause_msg"],
      [2248, "    call wait_key"],
      [2255, "do_mode:"],
      [2259, "    mov ax, 0x0003"],
      [2269, "do_more:"],
      [2275, "    call more_display_file"],
      [2369, "parse_more_args:"],
      [2389, "    cmp al, '<'"],
      [2292, "    mov di, nul_arg"],
      ["", "; ..."],
      [2652, "change_drive_command:"],
      [2656, "    mov al, [si]"],
      [2680, "    mov dl, al"],
      [2682, "    mov ah, 0x0E"],
      [2701, "print_prompt:"],
      [2705, "    mov ah, 0x47"],
      [2713, "    mov dx, prompt_end"],
      ["", "; ..."],
      [3626, "command_table:"],
      [3629, "    dw dir_cmd, do_dir"],
      [3630, "    dw cd_cmd, do_cd"],
      [3637, "    dw deltree_cmd, do_deltree"],
      [3638, "    dw copy_cmd, do_copy"],
      [3639, "    dw del_cmd, do_del"],
      [3641, "    dw ren_cmd, do_ren"],
      [3647, "    dw if_cmd, do_if"],
      [3648, "    dw goto_cmd, do_goto"],
      [3649, "    dw pause_cmd, do_pause"],
      [3651, "    dw mode_cmd, do_mode"],
      [3652, "    dw more_cmd, do_more"],
    ],
    hi: [242, 259, 265, 268, 274, 275, 1194, 1264, 1272, 1280, 1289, 1302, 1629, 1633, 1676, 1727, 1737, 1758, 1763, 1765, 1771, 1834, 1928, 1936, 1987, 2104, 1932, 2242, 2255, 2269, 2369, 2652, 2682, 2701, 2705, 3626, 3637, 3647, 3648, 3649, 3651, 3652],
    tests: ["scripts/test_shell.py", "scripts/test_shell_batch_builtins.py", "scripts/test_multidrive_shell.py"],
  },
  {
    id: "exec",
    title: "External command lookup",
    summary: "COM, EXE, and BAT are tried locally before PATH.",
    body: [
      "If the command has no extension, the shell first tries `.COM`, then `.EXE`, then `.BAT` in the current directory. Only after those fail does it walk PATH for COM, EXE, and BAT candidates. Extension checks are case-insensitive.",
      "Arguments are copied to a PSP-compatible command tail without uppercasing. Successful child programs return through AH=4Dh so the shell consumes the exit status and restores DS before printing the next prompt. Batch files stream line-by-line from their handle and save the previous batch handle so a nested BAT can return to its caller.",
    ],
    file: "programs/shell.asm",
    code: [
      [2785, "prepare_command:"],
      [2788, "    mov byte [command_has_ext], 0"],
      [2792, "    mov byte [tail_has_args], 0"],
      [2806, "    cmp al, '.'"],
      [2820, "    mov byte [command_has_path], 1"],
      [2843, "    mov al, '.'"],
      [2846, "    mov al, 'C'"],
      [2848, "    mov al, 'O'"],
      [2850, "    mov al, 'M'"],
      [2855, "    call build_cmd_tail"],
      ["", "; ..."],
      [2887, "run_command:"],
      [2892, "    call run_current_command"],
      [2900, "    call run_current_command"],
      [2908, "    call run_batch"],
      [2914, "    call run_path_exec"],
      [2920, "    call run_path_exec"],
      [2926, "    call run_path_batch"],
      [2930, "    call command_ext_is_bat"],
      [2949, "    mov ah, 0x4D"],
      [2950, "    int 0x21"],
      [2962, "command_ext_is_bat:"],
      [2971, "    and al, 0xDF"],
      [2975, "    and al, 0xDF"],
      [2990, "run_current_command:"],
      [3005, "    mov ax, 0x4B00"],
      [3006, "    int 0x21"],
      [3015, "run_autoexec:"],
      [3019, "    mov dx, autoexec_name"],
      [3020, "    call run_batch_named"],
      [3031, "run_batch_named:"],
      [3034, "    call batch_sync_position"],
      [3038, "    inc byte [batch_active]"],
      [3039, "    push word [batch_handle]"],
      [3041, "    mov ah, 0x3D"],
      [3045, "    mov word [batch_buf_pos], 0"],
      [3050, "    call batch_read_line"],
      [3055, "    call execute_line"],
      [3063, "    pop word [batch_handle]"],
      [3066, "    dec byte [batch_active]"],
      ["", "; ..."],
      [3404, "batch_read_line:"],
      [3408, "    call batch_read_char"],
      [3419, "    cmp cx, 127"],
      [3424, "    call batch_read_char"],
      [3432, "    xor al, al"],
      [3444, "batch_read_char:"],
      [3448, "    mov bx, [batch_buf_pos]"],
      [3454, "    mov ah, 0x3F"],
      [3455, "    int 0x21"],
      [3462, ".have_char:"],
      [3477, "batch_sync_position:"],
      [3489, "    mov ax, 0x4201"],
      ["", "; ..."],
      [3080, "run_path_exec:"],
      [3084, "run_path_batch:"],
      [3087, "run_path_command:"],
      [3088, "    cmp byte [command_has_path], 0"],
      [3090, "    call find_path_value"],
      [3093, "    call build_path_candidate"],
      [3097, "    call run_candidate_exec"],
      [3100, "    call run_batch_path"],
      ["", "; ..."],
      [3118, "find_path_value:"],
      [3131, "    mov ah, 0x62"],
      [3135, "    mov ax, [es:0x2C]"],
      [3145, "    mov si, path_env_name"],
      [3163, ".found:"],
      [3165, "    mov [path_env_seg], es"],
      ["", "; ..."],
      [3182, "build_path_candidate:"],
      [3207, "    cmp al, ';'"],
      [3242, "    mov al, '\\'"],
      [3246, "    mov si, command_name"],
      [3260, "    clc"],
    ],
    hi: [2785, 2843, 2855, 2887, 2908, 2926, 2930, 2949, 2962, 3031, 3034, 3038, 3039, 3050, 3055, 3063, 3066, 3404, 2900, 3444, 3477, 3080, 3084, 3087, 3097, 3100, 3118, 3182],
    tests: ["scripts/test_autoexec.py", "scripts/test_envpath.py", "tests/programs/pathrun.asm"],
  },
  {
    id: "environment",
    title: "Default environment",
    summary: "COMSPEC, PATH, PROMPT, and BLASTER are kernel-provided.",
    body: [
      "The boot program gets an MCB-backed environment before it starts. Default variables include `COMSPEC=A:\SHELL.COM`, `PATH=A:\;A:\BIN`, `PROMPT=$P$G`, and the conventional Sound Blaster string used by game setup tools.",
      "When the shell EXECs a child with env segment 0, the loader copies the shell's environment and appends a fresh DOS executable-path tail. The environment tests read PSP:2Ch and verify both the variables and the tail visible to child programs.",
    ],
    file: "src/kernel.asm",
    code: [
      [1693, "init_environment:"],
      [1702, "    call alloc_exec_environment"],
      [1710, "    call write_environment_vars"],
      [1711, "    mov ax, 1"],
      [1712, "    stosw"],
      [1719, "    mov si, fname_exe"],
      ["", "; ..."],
      [1753, "write_environment_vars:"],
      [1759, "    mov si, env_comspec_name"],
      [1764, "    mov si, env_path_name"],
      [1772, "    mov si, env_blaster"],
      [1774, "    mov si, env_prompt"],
      [1776, "    xor al, al"],
      [1799, "env_copy_drive_root:"],
      [1713, "    mov al, [cs:dos_drive_letter]"],
      ["", "; ..."],
      [3297, "env_comspec_name: db \"COMSPEC=\", 0"],
      [3298, "env_path_name: db \"PATH=\", 0"],
      [3299, "env_shell_name: db \"SHELL.COM\", 0"],
      [3300, "env_bin_dir: db \"BIN\", 0"],
      [3301, "env_blaster: db \"BLASTER=A220 I5 D1 H5 P330 T6\", 0"],
      [3302, "env_prompt: db \"PROMPT=$P$G\", 0"],
    ],
    hi: [1693, 1702, 1702, 1753, 1759, 1764, 1764, 1693, 3297, 3298],
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
