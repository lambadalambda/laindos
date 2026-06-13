// page_programs.jsx - program loading, EXEC, PSP, overlays, and termination.

const PROGRAM_FLOW = [
  ["Shell", "SHELL.COM parses a command and calls INT 21h AH=4Bh with DS:DX = child path and ES:BX = EXEC parameter block."],
  ["Loader", "LainDOS resolves the path, reads the first sector, detects COM vs MZ, allocates an MCB-backed block, and loads clusters."],
  ["PSP", "The child gets a PSP with terminate vectors, parent PSP, environment segment, JFT, command tail, and default FCBs."],
  ["Run", "COM starts at PSP:0100; EXE relocations are applied, then CS:IP and SS:SP come from the MZ header."],
  ["Return", "INT 20h, AH=4Ch, or AH=31h returns through cleanup, restores the parent frame, and records the return code."]];

const PROGRAM_SECTIONS = [
  {
    id: "exec",
    title: "EXEC captures the parent frame",
    summary: "AH=4Bh is the bridge from a shell command to a child process.",
    body: [
      "The parent supplies the path in DS:DX and an EXEC parameter block in ES:BX. LainDOS saves the parent's registers, PSP, DTA, and stack frame before resolving the child. That saved frame is what makes returning from a child look like a normal DOS call to the parent.",
      "AL=00h load-and-run, AL=01h load-only (the child's entry SS:SP and CS:IP are returned through the parameter block), and AL=03h overlay load are implemented. Other EXEC variants fail explicitly instead of becoming silent compatibility stubs."],
    file: "src/kernel/int21.inc",
    code: [
      [1951, ".exec:"],
      [1952, "    cmp al, 0"],
      [1953, "    je .exec_program"],
      [1954, "    cmp al, 1"],
      [1955, "    je near .exec_load"],
      [1956, "    cmp al, 3"],
      [1957, "    je .exec_overlay"],
      [2041, "    mov [cs:exec_param_off], bx"],
      [2042, "    mov [cs:exec_param_seg], es"],
      [2043, "    mov [cs:exec_path_off], dx"],
      [2044, "    mov [cs:exec_path_seg], ds"],
      [2045, "    call load_exec_program"]],
    hi: [1955, 2045, 2045],
    tests: ["scripts/test_shell.py", "scripts/test_execparam.py", "scripts/test_spawn.py"],
  },
  {
    id: "classify",
    title: "Resolve, size, and classify the image",
    summary: "The first sector decides whether the child is COM or MZ EXE.",
    body: [
      "`load_exec_program` turns the path into a directory entry, records the first cluster and size, reads sector zero into SEC_BUF, and then checks for the MZ signature. COM programs get a flat allocation plus slack; EXE programs compute a paragraph requirement from the header, minalloc, maxalloc, and file image size.",
      "After allocation the image is loaded immediately above the PSP at `prog_seg + 10h`. COM images get their PSP and command tail before control transfers; EXE images wait until relocation setup has validated the header."],
    file: "src/kernel/exec.inc",
    code: [
      [165, "load_exec_program:"],
      [169, "    mov ds, [cs:exec_path_seg]"],
      [170, "    mov si, [cs:exec_path_off]"],
      [177, "    call resolve_path"],
      [208, "    call exec_read_first_sector"],
      [211, "    call update_exec_environment_path"],
      [217, "    mov ax, SEC_BUF"],
      [219, "    cmp word [0], 0x5A4D"],
      [220, "    jne .com_size"],
      [221, "    mov byte [cs:exec_is_exe], 1"],
      [249, ".alloc:"],
      [260, "    mov [cs:prog_seg], ax"],
      [{a: "exec_load_fat_file"}, "    call load_file_direct"]],
    hi: [177, 219, 249, 170],
    tests: ["scripts/test_badreloc.py", "scripts/test_memrelease.py", "scripts/test_shell.py"],
  },
  {
    id: "env",
    title: "Environment blocks and executable path tail",
    summary: "Each child receives an environment block owned by its PSP.",
    body: [
      "If the EXEC parameter block names a custom environment, LainDOS copies it. If the parameter block asks to inherit with env segment 0, it copies the parent PSP environment; only a missing parent environment falls back to generated defaults. It then appends the DOS convention tail: a word count followed by the fully normalized executable path.",
      "The environment MCB starts with a temporary owner while loading. Once the PSP is committed, `assign_exec_environment_owner` stamps that MCB with the child PSP so termination cleanup can release it with the rest of the process."],
    file: "src/kernel/exec.inc",
    code: [
      [527, "    mov word [cs:exec_env_src_seg], 0"],
      [470, "    mov ax, [cs:exec_param_seg]"],
      [533, "    mov ax, [bx]"],
      [540, "    mov [cs:exec_env_src_seg], ax"],
      [542, ".inherit_parent_env:"],
      [551, "    mov ax, [0x2C]"],
      [540, "    mov [cs:exec_env_src_seg], ax"],
      [582, "    call alloc_exec_environment"],
      [593, ".copy_env:"],
      [608, "    call write_environment_vars"],
      [614, "    mov ax, 1"],
      [615, "    stosw"],
      [616, "    mov ds, [cs:exec_path_seg]"],
      [{a: "env_path_first_byte"}, "    stosb"]],
    hi: [582, 593, 608, 615],
    tests: ["scripts/test_execenv.py", "scripts/test_envmcb.py", "scripts/test_envpath.py", "scripts/test_envoflow.py"],
  },
  {
    id: "psp",
    title: "The Program Segment Prefix",
    summary: "The PSP is the child process contract DOS programs expect at DS=ES.",
    body: [
      "LainDOS clears the 256-byte PSP, writes the `CD 20` terminate instruction, records the top-of-memory word, copies INT 22h/23h/24h vectors, builds the Job File Table, links the parent PSP, and stores the environment pointer at PSP:2Ch.",
      "The command tail lives at PSP:80h. Default FCBs from the EXEC parameter block are copied to PSP:5Ch and PSP:6Ch so older startup code and C runtimes see the DOS layout they expect."],
    file: "src/kernel/exec.inc",
    code: [
      [1398, "build_psp:"],
      [1406, "    mov byte [es:0x00], 0xCD"],
      [1407, "    mov byte [es:0x01], 0x20"],
      [1420, "    mov ax, [0x22*4]"],
      [1436, "    mov word [es:0x32], MAX_HANDLES"],
      [1438, "    mov [es:0x36], ax"],
      [1497, "    mov bx, [cs:cur_psp]"],
      [1498, "    mov [es:0x16], bx"],
      [796, "    mov bx, [cs:exec_env_seg]"],
      [1500, "    mov [es:0x2C], bx"],
      [1504, "    call assign_exec_environment_owner"],
      [{a: "build_psp_copy_fcbs"}, "    call exec_copy_default_fcbs"]],
    hi: [1398, 1406, 1436, 1498, 1500],
    tests: ["scripts/test_shell.py", "scripts/test_execparam.py", "scripts/test_jft.py"],
  },
  {
    id: "handoff",
    title: "COM and EXE handoff",
    summary: "COM is flat; MZ EXE is relocated before CS:IP and SS:SP are loaded.",
    body: [
      "COM handoff is simple: DS, ES, and SS all point at the PSP, SP is placed near the top of the allocated block, and a far return lands at offset 0100h. EXE handoff is stricter: relocation table bounds are validated, relocation entries are applied against `exe_load_seg`, the image is slid down past the MZ header, and then the header's CS:IP and SS:SP are used.",
      "Both paths reset the keyboard buffer and FPU before entering the child so old startup code sees a predictable machine state."],
    file: "src/kernel/exec.inc",
    code: [
      [1593, "    mov ax, [cs:exe_reloc_count]"],
      [139, "    cmp dx, 0x1C"],
      [1689, "    mov ax, [cs:prog_seg]"],
      [1600, "    call build_psp"],
      [1617, "    mov di, [bx]"],
      [1618, "    mov ax, [bx+2]"],
      [1627, "    mov ax, [es:di]"],
      [1624, "    add ax, [cs:exe_load_seg]"],
      [1629, "    mov [es:di], ax"],
      [1663, "    call exec_exe_dyn"],
      [1712, "exec_com_dyn:"],
      [1736, "    mov ss, ax"],
      [1740, "    push word 0x0100"],
      [{a: "exec_com_entry_jump"}, "    retf"]],
    hi: [139, 1600, 1629, 1663, 1712, {a: "exec_com_entry_jump"}],
    tests: ["scripts/test_badreloc.py", "scripts/test_overlay.py", "scripts/test_regpres.py"],
  },
  {
    id: "overlays",
    title: "Overlays load without becoming processes",
    summary: "EXEC AL=03h copies code into a caller-supplied segment.",
    body: [
      "Overlay loads use the same path resolver but no PSP switch. The caller supplies a load segment and relocation segment in the overlay parameter block. MZ overlays skip the header, copy the image to the requested segment, and apply relocation entries using the supplied relocation base.",
      "Because no child process starts, success returns directly to the caller with carry clear; failures return DOS-style errors without changing process context."],
    file: "src/kernel/int21.inc",
    code: [
      [2107, ".exec_overlay:"],
      [2115, "    mov [cs:ov_param_off], bx"],
      [2120, "    mov ax, [es:bx]"],
      [2121, "    mov [cs:ov_load_seg], ax"],
      [2122, "    mov ax, [es:bx+2]"],
      [2123, "    mov [cs:ov_reloc_seg], ax"],
      [2251, "    call resolve_path"],
      [2159, "    call load_overlay_direct"],
      [832, "    xor ax, ax"],
      [551, "    jmp iret_nc"]],
    hi: [2107, 2121, 2123, 2159],
    tests: ["scripts/test_overlay.py", "tests/programs/ovltest.asm", "tests/programs/overlay.asm"],
  },
  {
    id: "return",
    title: "Termination returns to the parent",
    summary: "Cleanup releases child-owned state and restores the saved parent stack.",
    body: [
      "Normal termination clears transient hardware state, releases inherited handles, closes child-owned handles, frees child-owned MCBs, coalesces the arena, restores the parent PSP from PSP:16h, and jumps back through the saved EXEC frame.",
      "TSR termination is different: it keeps the requested part of the PSP block resident, frees the rest of the child's allocations, records return type 3, and then restores the parent just like a normal return."],
    file: "src/kernel.asm",
    code: [
      [2673, "do_terminate:"],
      [2678, "    call restore_irq1_null_mask"],
      [2688, "    call release_inherited_handles"],
      [2689, "    call close_owned_handles"],
      [2691, "    mov si, [cs:mcb_first]"],
      [2697, "    mov word [ds:1], 0"],
      [2700, "    call mcb_coalesce_all_free"],
      [2705, "    mov ax, [0x16]"],
      [2707, "    mov [cs:cur_psp], ax"],
      [2716, "    mov ax, [cs:saved_ss]"],
      [2719, "    mov sp, [cs:saved_sp]"],
      [{a: "do_terminate_return_to_parent"}, "    jmp exec_resume_parent"]],
    hi: [2673, 2688, 2673, 2705, {a: "do_terminate_return_to_parent"}],
    tests: ["scripts/test_retcode.py", "scripts/test_termflush.py", "scripts/test_tsr.py"],
  }];

const PROGRAM_TESTS = [
  ["COM/EXE", "scripts/test_shell.py", "Runs HELLO.COM, HELLOEXE.EXE, EXECTEST.COM, and related shell-launched programs."],
  ["PSP", "tests/programs/psptest.asm", "Checks PSP fields and parent/child behavior."],
  ["EXEC params", "scripts/test_execparam.py", "Covers command tails, default FCB pointers, missing paths, and load variants."],
  ["EXEC env", "scripts/test_execenv.py", "Verifies custom environment ownership and child-visible data."],
  ["Overlay", "scripts/test_overlay.py", "Exercises AH=4Bh AL=03h overlay loading and relocation."],
  ["Return code", "scripts/test_retcode.py", "Checks AH=4Dh return-code behavior after child exits."],
  ["Bad reloc", "scripts/test_badreloc.py", "Rejects invalid relocation tables and preserves parent state."],
  ["Termination", "scripts/test_termflush.py", "Confirms open writable handles flush on program termination."]];

function ProgramsPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Loader track
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Programs
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 760, margin: 0 }}>
            How LainDOS moves from a shell command to a child process and back: EXEC, PSP layout,
            environments, COM and MZ EXE handoff, overlays, return codes, and termination cleanup.
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={progCard(T)}>
              <h2 style={progH2(T)}>The loader path</h2>
              <p style={progP(T)}>
                LainDOS is single-tasking, but DOS still has process state. A child gets its own PSP, MCB owner,
                JFT view, DTA, environment block, command tail, and terminate vectors; the parent is suspended by
                a saved real-mode stack frame until the child exits.
              </p>
              <div style={{ display: "grid", gap: 10, marginTop: 14 }}>
                {PROGRAM_FLOW.map((row, i) => <ProgramFlow key={row[0]} row={row} index={i} />)}
              </div>
            </section>

            {PROGRAM_SECTIONS.map(section => <ProgramSection key={section.id} section={section} />)}
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={progPanel(T)}>
              <h3 style={progKicker(T)}>Regression map</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {PROGRAM_TESTS.map(row => <ProgramTest key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...progPanel(T), marginTop: 14 }}>
              <h3 style={progKicker(T)}>User-visible proof</h3>
              <div style={progFact(T)}><strong>Shell launch</strong><span><window.InlineText text={"Typing `midemo` works because SHELL.COM can EXEC an EXE and regain control."} /></span></div>
              <div style={progFact(T)}><strong>Program return</strong><span>AH=4Dh reports the child's return code after AH=4Ch or INT 20h exits.</span></div>
              <div style={progFact(T)}><strong>Overlays</strong><span>Old runtimes can load overlay code without spawning a new process.</span></div>
              <button onClick={() => go("dosapi")} style={{ ...progButton(T.amber), marginTop: 12 }}>See INT 21h calls</button>
            </div>
            <div style={{ ...progPanel(T), marginTop: 14 }}>
              <h3 style={progKicker(T)}>Related tracks</h3>
              <button onClick={() => go("boot/s7")} style={{ ...progButton(T.pink), marginBottom: 8 }}>Boot handoff</button>
              <button onClick={() => go("tests")} style={progButton(T.blue)}>Test ladder</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function ProgramFlow({ row, index }) {
  const T = window.T;
  return (
    <div style={{ display: "grid", gridTemplateColumns: "42px 110px 1fr", gap: 12, alignItems: "baseline",
      border: `1px solid ${T.line}`, borderRadius: 10, background: "#fffdf6", padding: "10px 12px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.faint }}>{String(index + 1).padStart(2, "0")}</code>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.amber, textTransform: "uppercase" }}>{row[0]}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.5 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function ProgramSection({ section }) {
  const T = window.T;
  return (
    <section id={section.id} style={{ borderTop: `1px solid ${T.line}`, padding: "28px 0" }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10, flexWrap: "wrap", marginBottom: 8 }}>
        <h2 style={{ ...progH2(T), margin: 0 }}>{section.title}</h2>
        <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber }}>{section.summary}</code>
      </div>
      {section.body.map((p, i) => <p key={i} style={progP(T)}><window.InlineText text={p} /></p>)}
      <div style={{ display: "grid", gap: 14, marginTop: 16, alignItems: "start" }}>
        <window.CodeBlock file={section.file} code={section.code} hi={section.hi} />
        <div style={{ display: "grid", gap: 12 }}>
          <div style={progPanel(T)}>
            <h3 style={progKicker(T)}>Tests that pin this</h3>
            <div style={{ display: "grid", gap: 7 }}>
              {section.tests.map(test => <code key={test} style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue }}>{test}</code>)}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function ProgramTest({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber, textTransform: "uppercase" }}>{row[0]}</div>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue }}>{row[1]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[2]} /></div>
    </div>
  );
}

function progCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function progPanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function progH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function progP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, maxWidth: 760, margin: "0 0 12px" };
}
function progKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function progFact(T) {
  return { display: "grid", gap: 3, borderTop: `1px solid ${T.line}`, padding: "10px 0", fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 13.5, lineHeight: 1.45 };
}
function progButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { ProgramsPage });
