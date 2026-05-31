// page_tests.jsx - contributor guide to the LainDOS regression ladder.

const TEST_LAYERS = [
  {
    title: "1. Tiny DOS programs",
    summary: "One real-mode program proves one API surface.",
    body: "These live under tests/programs/. They set up segment registers, call INT 21h or a narrow hardware path, print PASS:/FAIL: markers, and exit with AH=4Ch so QEMU serial output can be checked automatically.",
    examples: ["tests/programs/irqmask.asm", "tests/programs/execparam.asm", "tests/programs/findnext.asm"],
  },
  {
    title: "2. Python/QEMU runners",
    summary: "A host script builds a fresh image and checks serial output.",
    body: "Most scripts use build_nasm_test_image, run_serial_image, and check_markers from scripts/testlib.py. The image is disposable and always contains the current boot sector and kernel.",
    examples: ["scripts/test_irqmask.py", "scripts/test_execparam.py", "scripts/run_tests.py"],
  },
  {
    title: "3. Shell, loader, and filesystem scenarios",
    summary: "Broader tests combine APIs and inspect disk state.",
    body: "These cover command dispatch, EXEC parent/child restoration, writable FAT behavior, directory mutation, rollback, and persistent image contents after QEMU exits.",
    examples: ["scripts/test_shell.py", "scripts/test_savewrite.py", "scripts/test_dirmut.py"],
  },
  {
    title: "4. Game smoke tests",
    summary: "Real games prove the integrated path reaches visible gameplay.",
    body: "Game smokes build generated images from local media, drive QEMU through monitor sockets, keep host audio silent, and use serial plus framebuffer checks to catch crashes and blank screens.",
    examples: ["scripts/test_shell_monkey.py", "scripts/test_wolf3d_smoke.py", "scripts/test_shortline_smoke.py"],
  },
];

const TEST_COMMANDS = [
  ["make test", "Build the default disk and run the full automated ladder from scripts/run_tests.py."],
  ["make check-docs-sync", "Verify docs/site source excerpts, documented targets, file refs, and test counts."],
  ["TEST_JOBS=1 make test", "Run the same ladder serially when logs or timing need isolation."],
  ["python3 scripts/test_irqmask.py", "Run one focused regression directly."],
  ["make test-monkey-demo", "Smoke-test the shell-launched Monkey Island demo."],
  ["make test-game-smokes", "Run the standard game smoke ladder when local media is present."],
  ["make test-shortline-smoke", "Run the Shortline-specific paced QEMU smoke."],
  ["make test-norton-commander-smoke", "Smoke-test Norton Commander from the local archive."],
];

const TEST_CHECKLIST = [
  "Start from a concrete failing caller, trace, or compatibility gap.",
  "Write the smallest 16-bit test program that exercises the behavior.",
  "Use unique PASS:/FAIL: markers so failures identify the exact branch.",
  "Build a fresh image in the runner instead of reusing a checked-in image.",
  "Add fast deterministic tests to DEFAULT_TESTS in scripts/run_tests.py.",
  "Run make check-docs-sync when docs quote source files or commands.",
  "Keep proprietary game media ignored and generated artifacts under build/.",
  "Update README, docs, debug logs, or issue notes when workflows change.",
  "Run JSX checks and a local browser or Playwright smoke when docs/site changes.",
  "Run the focused test, make test, and relevant game smokes before review.",
];

const TEST_PROGRAM_TEMPLATE = [
  [1, "[bits 16]"],
  [2, "[org 0x0100]"],
  [3, ""],
  [4, "start:"],
  [5, "    push cs"],
  [6, "    pop ds"],
  [7, ""],
  [8, "    ; Call the API under test here."],
  [9, ""],
  [10, "    mov dx, pass_msg"],
  [11, "    mov ah, 0x09"],
  [12, "    int 0x21"],
  [13, "    mov ax, 0x4C00"],
  [14, "    int 0x21"],
  [15, ""],
  [16, "fail:"],
  [17, "    mov dx, fail_msg"],
  [18, "    mov ah, 0x09"],
  [19, "    int 0x21"],
  [20, "    mov ax, 0x4C01"],
  [21, "    int 0x21"],
  [22, ""],
  [23, "pass_msg: db \"PASS: EXAMPLE\", 13, 10, \"$\""],
  [24, "fail_msg: db \"FAIL: EXAMPLE\", 13, 10, \"$\""],
];

const TEST_RUNNER_TEMPLATE = [
  [1, "#!/usr/bin/env python3"],
  [2, "import os"],
  [3, "import sys"],
  [4, "from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image"],
  [5, ""],
  [6, "BUILDDIR = build_dir()"],
  [7, "IMG = os.path.join(BUILDDIR, \"example.img\")"],
  [8, "KERNEL = os.path.join(BUILDDIR, \"example_kernel.bin\")"],
  [9, ""],
  [10, "def main():"],
  [11, "    build_nasm_test_image(BUILDDIR, IMG, KERNEL, \"EXAMPLE COM\", \"tests/programs/example.asm\", \"example.com\")"],
  [12, "    output = run_serial_image(IMG, timeout=10)"],
  [13, "    if not check_markers(output, required=(\"PASS: EXAMPLE\", \"Program exited, code=00\", \"HALT\")):"],
  [14, "        sys.exit(1)"],
  [15, "    print(\"\\nExample test passed.\")"],
  [16, ""],
  [17, "if __name__ == \"__main__\":"],
  [18, "    main()"],
];

function TestsPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Regression workflow
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            The Test Ladder
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 740, margin: 0 }}>
            Every compatibility fix should climb from a small DOS repro to the broader runs it can affect.
            The ladder keeps LainDOS caller-driven instead of collecting untested DOS stubs.
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={testsCard(T)}>
              <h2 style={testsH2(T)}>How to choose the next test</h2>
              <p style={testsP(T)}>
                Begin with the narrowest proof that would have failed before the change. If the fix touches a DOS API,
                write a tiny program. If it touches shell, loader, or FAT state, add a scenario runner. If the bug only
                appears in a game, keep the media local and add a smoke that proves the visible path.
              </p>
            </section>

            <section style={testsCard(T)}>
              <h2 style={testsH2(T)}>Layers</h2>
              <div style={{ display: "grid", gap: 12, marginTop: 14 }}>
                {TEST_LAYERS.map(layer => <TestLayer key={layer.title} layer={layer} />)}
              </div>
            </section>

            <section style={testsCard(T)}>
              <h2 style={testsH2(T)}>Focused test template</h2>
              <p style={testsP(T)}>
                The important convention is not the exact code shape; it is the serial-visible contract:
                <window.InlineText text={" one unique `PASS:` marker, useful `FAIL:` markers, and a DOS exit code."} />
              </p>
              <div style={{ display: "grid", gap: 16, alignItems: "start" }}>
                <window.CodeBlock file="tests/programs/example.asm" code={TEST_PROGRAM_TEMPLATE} hi={[10, 13, 17, 20]} />
                <window.CodeBlock file="scripts/test_example.py" code={TEST_RUNNER_TEMPLATE} hi={[11, 12, 13]} kind="Python" />
              </div>
            </section>

            <section style={testsCard(T)}>
              <h2 style={testsH2(T)}>Game smoke rules</h2>
              <p style={testsP(T)}>
                Game smokes are integration tests, not media archival. Keep proprietary input ignored, build disposable
                <window.InlineText text={" images under `build/`, use QEMU monitor input for deterministic startup, and prefer framebuffer checks"} />
                {" "}when the serial log cannot prove that graphics reached gameplay.
              </p>
              <div style={{ display: "grid", gap: 9, marginTop: 12 }}>
                {["Use qemu_sb16_silent_args when the game expects SB16 but tests must stay quiet.",
                  "Reject EXC, unhandled INT 21h, FAIL:, and known game-level fatal markers.",
                  "Keep special pacing, such as Shortline's -icount run, in a dedicated Makefile target.",
                  "Record non-trivial triage in docs/debug_log.md before changing approach."].map(item => (
                  <div key={item} style={testsBullet(T)}><span style={{ color: T.amber }}>check</span><window.InlineText text={item} /></div>
                ))}
              </div>
            </section>
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={testsPanel(T)}>
              <h3 style={testsKicker(T)}>Commands</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {TEST_COMMANDS.map(row => <TestCommand key={row[0]} row={row} />)}
              </div>
            </div>
            <div style={{ ...testsPanel(T), marginTop: 14 }}>
              <h3 style={testsKicker(T)}>New-test checklist</h3>
              <div style={{ display: "grid", gap: 8 }}>
                {TEST_CHECKLIST.map(item => <div key={item} style={testsChecklist(T)}>{item}</div>)}
              </div>
            </div>
            <div style={{ ...testsPanel(T), marginTop: 14 }}>
              <h3 style={testsKicker(T)}>Source guide</h3>
              <p style={{ ...testsP(T), fontSize: 13.5, marginBottom: 12 }}>
                <window.InlineText text={"The plain Markdown version lives at `docs/test_ladder.md` for terminal-side contributors."} />
              </p>
              <button onClick={() => go("dosapi")} style={testsButton(T.amber)}>Read DOS API coverage</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function TestLayer({ layer }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 10, background: "#fffdf6", padding: "14px 15px" }}>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 17, color: T.ink, fontWeight: 700 }}>{layer.title}</div>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.amber, marginTop: 3 }}>{layer.summary}</div>
      <p style={{ ...testsP(T), marginTop: 9 }}><window.InlineText text={layer.body} /></p>
      <div style={{ display: "flex", gap: 7, flexWrap: "wrap", marginTop: 10 }}>
        {layer.examples.map(example => <code key={example} style={testsPill(T)}>{example}</code>)}
      </div>
    </div>
  );
}

function TestCommand({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.pink }}>{row[0]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 5 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function testsCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function testsPanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function testsH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function testsP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, margin: "0 0 12px" };
}
function testsKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function testsPill(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.blue, border: `1px solid ${T.line}`, borderRadius: 20, padding: "4px 8px", background: T.panel };
}
function testsBullet(T) {
  return { display: "flex", gap: 10, alignItems: "baseline", fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 14.5, color: T.dim, lineHeight: 1.5 };
}
function testsChecklist(T) {
  return { borderLeft: `3px solid ${T.amber}`, paddingLeft: 10, fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.45 };
}
function testsButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { TestsPage });
