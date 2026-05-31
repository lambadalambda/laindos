// page_emulators.jsx - emulator workflow guide for reproducing LainDOS runs.

const EMULATOR_CHOICES = [
  {
    name: "QEMU first",
    tag: "default",
    body: "Use QEMU for fast scripted tests, serial logs, monitor sockets, VNC screenshots, and normal game smoke runs. The repo picks LAINDOS_QEMU first, then the sibling patched QEMU build, then qemu-system-i386 from PATH.",
    notes: ["QEMU_VGA defaults to `std,retrace=precise` for game runs.", "Use `-serial stdio` or a log file when tests need grep-able output.", "Attach `-device sb16` for generic Sound Blaster runs; add `-device adlib` only for games that need OPL/AdLib probing."],
  },
  {
    name: "86Box compare",
    tag: "hardware flavor",
    body: "Use 86Box when QEMU looks suspicious or when a game wants period hardware. Keep experiments in copies of `build/86box-serial-file/` so the baseline VM profile stays stable.",
    notes: ["Ascendancy currently likes `gfxcard = s3_trio64_pci`.", "Try `cpu_use_dynarec = 0` and `fpu_softfloat = 1` as comparison toggles.", "If 86Box progresses and QEMU stalls, suspect emulator behavior before changing LainDOS."],
  },
  {
    name: "Real DOS in QEMU",
    tag: "blame splitter",
    body: "Boot a real DOS floppy in QEMU and expose the game tree with QEMU FAT export when you need to separate a LainDOS bug from a QEMU/game/runtime bug.",
    notes: ["QEMU FAT export needs an absolute host path.", "If real DOS in QEMU reproduces the problem, de-prioritize LainDOS DOS/filesystem debugging.", "Load MOUSE.COM in AUTOEXEC.BAT when the comparison needs mouse input."],
  },
  {
    name: "Bochs or v86",
    tag: "specialized",
    body: "Use Bochs for short debugger-heavy reproductions when QEMU and 86Box disagree. Use v86 for the browser demo and docs smoke, not as the authoritative compatibility target.",
    notes: ["Bochs is best for CPU inspection, not broad regression sweeps.", "The site pins v86 and uses the matching bochs-vgabios.bin from the v86 BIOS tree.", "Browser v86 is intentionally a small demo path around shell_monkey.img."],
  },
];

const EMULATOR_TARGETS = [
  ["Boot and DOS API regressions", "QEMU headless", "make test", "Serial PASS:/FAIL: markers and HALT."],
  ["Interactive shell demo", "v86 or QEMU", "make monkey-demo", "Builds shell_monkey.img for the site and local runs."],
  ["Monkey Island demo", "QEMU + SB16", "make test-monkey-demo", "Shell launch, game startup, and framebuffer activity."],
  ["Full game ladder", "QEMU", "make test-game-smokes", "Monkey, Wolf3D, and Ascendancy when local media exists."],
  ["Wolfenstein 3D", "QEMU VGA retrace + SB16/AdLib", "make test-wolf3d-smoke", "Uses precise retrace and the separate AdLib device so startup probes match 86Box."],
  ["Ascendancy", "patched QEMU, then 86Box", "make test-ascendancy-smoke", "Use the local SAHF-fixed QEMU before treating a stall as LainDOS."],
  ["Shortline", "paced QEMU", "make test-shortline-smoke", "Uses -icount pacing for the game's PIT calibration."],
  ["Norton Commander", "QEMU", "make test-norton-commander-smoke", "Checks launcher-style EXEC and display startup."],
];

const EMULATOR_PROBES = [
  ["serial", "Keep COM1 output in stdio or a log so tests can reject EXC, FAIL:, and unhandled INT 21h markers."],
  ["monitor", "Use a monitor socket for sendkey, screendump, info registers, x /12i $eip, and xp /1dw 0x46c."],
  ["framebuffer", "Hash or inspect screenshots when serial output cannot prove the game reached visible gameplay."],
  ["CPU sample", "Sample registers and a few instructions before waiting minutes; a DOS trace may only show the last visible boundary."],
];

const EMULATOR_HAZARDS = [
  "Ascendancy needs the local QEMU SAHF fix unless your installed QEMU already has equivalent behavior. The patch is documented in docs/qemu-sahf-ccop.patch.",
  "QEMU FAT export is fast for real DOS comparisons, but it is not an exact replacement for a partitioned DOS hard disk image.",
  "Do not blanket-add `-device adlib` to every QEMU game run. Wolf3D needs it for Sound Blaster detection, but the Monkey Island demo currently trips runtime error R6003 when AdLib is attached.",
  "The all-games QEMU task intentionally stays SB16-only; use the dedicated Wolf3D task when checking Wolf3D sound detection parity with 86Box.",
  "Use `std,retrace=precise` for VGA timing loops; Wolf3D and similar games can stall if retrace polling never sees transitions.",
  "v86 uses pinned browser assets and bochs-vgabios.bin from the matching v86 tree; changing one without the other can break the site demo.",
  "Keep proprietary media in vendor/ or generated build/ trees. Site and CI artifacts should stay redistributable.",
];

function EmulatorsPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Repro workflow
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Emulator Workflows
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 760, margin: 0 }}>
            <window.InlineText text={"Pick the shortest emulator path that answers the question: QEMU for automated proof, 86Box for hardware-flavored comparison, real DOS in QEMU to split blame, and Bochs when you need debugger-grade CPU inspection."} />
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 30, alignItems: "start" }}>
          <div>
            <section style={emuCard(T)}>
              <h2 style={emuH2(T)}>Decision rules</h2>
              <div style={{ display: "grid", gap: 12, marginTop: 14 }}>
                {EMULATOR_CHOICES.map(choice => <EmulatorChoice key={choice.name} choice={choice} />)}
              </div>
            </section>

            <section style={emuCard(T)}>
              <h2 style={emuH2(T)}>Which command proves what?</h2>
              <p style={emuP(T)}><window.InlineText text={"The source-of-truth commands stay in the Makefile and docs/emulator_workflows.md; this table is the quick selector."} /></p>
              <div style={{ display: "grid", gap: 9, marginTop: 14 }}>
                {EMULATOR_TARGETS.map(row => <EmulatorTarget key={row[0]} row={row} />)}
              </div>
            </section>

            <section style={emuCard(T)}>
              <h2 style={emuH2(T)}>Probe before waiting</h2>
              <p style={emuP(T)}><window.InlineText text={"When a game appears stuck, capture a small discriminator first. The right serial log, monitor socket probe, or framebuffer hash can save hours of guessing."} /></p>
              <div className="emulator-probe-grid" style={{ display: "grid", gridTemplateColumns: "repeat(2, minmax(0, 1fr))", gap: 10, marginTop: 14 }}>
                {EMULATOR_PROBES.map(row => <EmulatorProbe key={row[0]} row={row} />)}
              </div>
            </section>
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={emuPanel(T)}>
              <h3 style={emuKicker(T)}>Primary docs</h3>
              <div style={{ display: "grid", gap: 9 }}>
                <RepoLink path="docs/emulator_workflows.md" label="docs/emulator_workflows.md" />
                <RepoLink path="docs/debug_log.md" label="docs/debug_log.md" />
                <RepoLink path="docs/qemu-sahf-ccop.patch" label="docs/qemu-sahf-ccop.patch" />
                <RepoLink path="Makefile" label="Makefile targets" />
              </div>
            </div>
            <div style={{ ...emuPanel(T), marginTop: 14 }}>
              <h3 style={emuKicker(T)}>Known hazards</h3>
              <div style={{ display: "grid", gap: 9 }}>
                {EMULATOR_HAZARDS.map(item => <div key={item} style={emuNote(T)}><window.InlineText text={item} /></div>)}
              </div>
            </div>
            <div style={{ ...emuPanel(T), marginTop: 14 }}>
              <h3 style={emuKicker(T)}>Browser demo</h3>
              <p style={{ ...emuP(T), fontSize: 13.5, marginBottom: 12 }}>
                <window.InlineText text={"The Run page uses v86 with pinned BIOS blobs and the generated `shell_monkey.img` image."} />
              </p>
              <button onClick={() => go("run")} style={emuButton(T.pink)}>Open Run page</button>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function EmulatorChoice({ choice }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 10, background: "#fffdf6", padding: "14px 15px" }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
        <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 18, color: T.ink, fontWeight: 700 }}>{choice.name}</div>
        <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: T.amber }}>{choice.tag}</code>
      </div>
      <p style={{ ...emuP(T), marginTop: 8 }}><window.InlineText text={choice.body} /></p>
      <div style={{ display: "grid", gap: 6 }}>
        {choice.notes.map(note => <div key={note} style={emuBullet(T)}><span style={{ color: T.amber }}>note</span><window.InlineText text={note} /></div>)}
      </div>
    </div>
  );
}

function EmulatorTarget({ row }) {
  const T = window.T;
  return (
    <div className="emulator-target-row" style={{ display: "grid", gridTemplateColumns: "1.15fr 1fr 1fr", gap: 10, alignItems: "start",
      border: `1px solid ${T.line}`, borderRadius: 9, background: "#fffdf6", padding: "10px 12px" }}>
      <div>
        <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 14.5, color: T.ink, fontWeight: 700 }}>{row[0]}</div>
        <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.5, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[3]} /></div>
      </div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13, color: T.dim, lineHeight: 1.45 }}><window.InlineText text={row[1]} /></div>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.pink, lineHeight: 1.5 }}>{row[2]}</code>
    </div>
  );
}

function EmulatorProbe({ row }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 8, background: "#fffdf6", padding: "10px 11px" }}>
      <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.green, textTransform: "uppercase" }}>{row[0]}</code>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 12.8, color: T.dim, lineHeight: 1.45, marginTop: 4 }}><window.InlineText text={row[1]} /></div>
    </div>
  );
}

function RepoLink({ path, label }) {
  const T = window.T;
  return (
    <a href={`https://github.com/lambadalambda/laindos/blob/main/${path}`} target="_blank" rel="noreferrer"
      style={{ display: "block", fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.blue, lineHeight: 1.45, textDecoration: "none" }}>
      {label || path}
    </a>
  );
}

function emuCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function emuPanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function emuH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: "0 0 10px" };
}
function emuP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5, lineHeight: 1.65, margin: "0 0 12px" };
}
function emuKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function emuBullet(T) {
  return { display: "flex", gap: 10, alignItems: "baseline", fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, lineHeight: 1.5 };
}
function emuNote(T) {
  return { borderLeft: `3px solid ${T.amber}`, paddingLeft: 10, fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.2, color: T.dim, lineHeight: 1.45 };
}
function emuButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { EmulatorsPage });
