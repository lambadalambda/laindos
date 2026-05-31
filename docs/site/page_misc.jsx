// page_misc.jsx — Overview, stubbed tracks, and the standalone Emulator page.

function OverviewPage({ go }) {
  const T = window.T;
  const tracks = window.NAV.filter(n => n.kind === "track");
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "70px 56px 60px" }}>
        <div style={{ maxWidth: 1080, margin: "0 auto" }}>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, letterSpacing: 2,
            textTransform: "uppercase", color: "#ffe1c0" }}>A DOS, read from the inside</div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 96, lineHeight: "90px", fontWeight: 500, margin: "14px 0 20px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.22)" }}>
            LainDOS<span style={{ color: "#7ee0d4" }}>.</span>
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.94)", fontSize: 19,
            lineHeight: 1.6, maxWidth: 660, margin: "0 0 26px" }}>
            <window.InlineText text={"A tiny single-tasking DOS for x86 real mode, written from scratch in NASM — small enough to"} />
            {" "}
            read end to end, complete enough to boot <span style={{ color: "#fff", fontWeight: 600 }}>The Secret of Monkey Island</span>.
          </p>
          <div style={{ display: "flex", gap: 12 }}>
            <button onClick={() => go("boot")} style={{ background: "#fff", color: "#3a2230", border: "none", borderRadius: 9,
              padding: "13px 22px", fontFamily: "'Zen Kaku Gothic New', sans-serif", fontWeight: 700, fontSize: 15, cursor: "pointer" }}>
              Start the boot walkthrough →
            </button>
            <button onClick={() => go("run")} style={{ background: "rgba(0,0,0,0.18)", color: "#fff",
              border: "1px solid rgba(255,255,255,0.6)", borderRadius: 9, padding: "13px 22px",
              fontFamily: "'Zen Kaku Gothic New', sans-serif", fontWeight: 600, fontSize: 15, cursor: "pointer" }}>▶ Boot it now</button>
          </div>
        </div>
      </header>

      <div style={{ maxWidth: 1080, margin: "0 auto", padding: "48px 56px 60px" }}>
        <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 16, lineHeight: 1.6, maxWidth: 640, margin: 0 }}>
          <window.InlineText text={"These docs walk the source the way the machine runs it. Start with the boot path — the whole journey from power-on to a running game — then branch into the subsystems."} />
        </p>

        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 340px", gap: 30, marginTop: 40, alignItems: "start" }}>
          <div>
            <h3 style={sectionH(T)}>How to read this</h3>
            <div style={{ display: "grid", gap: 10 }}>
              {tracks.map(t => (
                <button key={t.id} onClick={() => go(t.id)} style={{ textAlign: "left", display: "flex", gap: 14,
                  alignItems: "flex-start", padding: "15px 16px", border: `1px solid ${T.line}`, borderRadius: 10,
                  background: T.panel, cursor: "pointer" }}>
                  <window.StatusDot status={t.status} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontWeight: 600, fontSize: 15.5, color: T.ink }}>{t.label}</div>
                    <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, color: T.dim, marginTop: 2 }}>{t.blurb}</div>
                  </div>
                  <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 10.5, color: T.faint, textTransform: "uppercase",
                    border: `1px solid ${T.line}`, borderRadius: 5, padding: "2px 7px", whiteSpace: "nowrap" }}>
                    {t.status === "done" ? "ready" : t.status === "wip" ? "drafting" : "soon"}
                  </span>
                </button>
              ))}
            </div>
          </div>
          <div>
            <h3 style={sectionH(T)}>The machine</h3>
            <window.MemoryMap />
          </div>
        </div>
      </div>
    </div>
  );
}

function StubPage({ item, go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <div style={{ maxWidth: 760, margin: "0 auto", padding: "64px 56px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
          fontSize: 12, letterSpacing: 2, textTransform: "uppercase", color: item.status === "wip" ? T.amber : T.faint }}>
          <window.StatusDot status={item.status} /> {item.status === "wip" ? "in progress" : "planned track"}
        </div>
        <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 66, lineHeight: "66px", fontWeight: 500, margin: "14px 0 16px", color: T.ink }}>{item.label}</h1>
        <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 17, lineHeight: 1.65, maxWidth: 600 }}>{item.blurb}.</p>
        <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.faint, fontSize: 15, lineHeight: 1.65, maxWidth: 600 }}>
          This track will follow the same shape as the boot path: real source, line-level annotations,
          and a memory/state view alongside. The structure is in place — content lands next.
        </p>
        <button onClick={() => go("boot")} style={{ ...ctaOutline(T.amber), marginTop: 22 }}>← Read the boot path meanwhile</button>
      </div>
    </div>
  );
}

function RunPage({ go }) {
  const T = window.T;
  const [phase, setPhase] = React.useState("idle");
  const [errMsg, setErrMsg] = React.useState("");
  const [bootKey, setBootKey] = React.useState(0);
  const onStatus = React.useCallback((s, msg) => {
    setPhase(s); if (msg) setErrMsg(msg);
  }, []);
  const boot = () => { setErrMsg(""); setPhase("booting"); setBootKey(k => k + 1); };
  const live = phase === "running" || phase === "booting" || phase === "stalled" || phase === "error";
  const statusLabel = { idle: "○ halted", booting: "◐ booting", running: "● running", stalled: "◐ loading…", error: "✕ error" }[phase];
  const statusColor = phase === "running" ? T.green : phase === "error" ? "#e0574b" : T.faint;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <div style={{ maxWidth: 1100, margin: "0 auto", padding: "46px 56px 56px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
          fontSize: 12, letterSpacing: 2, textTransform: "uppercase", color: T.pink }}>
          <span style={{ width: 8, height: 8, borderRadius: "50%", background: T.pink, boxShadow: `0 0 7px ${T.pink}` }} /> Live machine
        </div>
        <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 14px", color: T.ink }}>Run LainDOS</h1>
        <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 16.5, lineHeight: 1.6, maxWidth: 620, margin: 0 }}>
          <window.InlineText text={"A real x86 emulator (v86) boots the LainDOS floppy right here in the browser — the same boot you just read about. Click the screen and type to use it. Flip to the"} />
          {" "}<b style={{ color: T.ink, fontWeight: 600 }}>Serial · COM1</b>
          {" "}tab to watch LainDOS narrate the very boot the walkthrough describes.
        </p>

        <div className="site-run-grid" style={{ display: "grid", gridTemplateColumns: "1fr 320px", gap: 28, marginTop: 32, alignItems: "start" }}>
          <div>
            <div style={{ border: `1px solid ${T.line}`, borderRadius: 12, overflow: "hidden", background: "#000",
              boxShadow: "0 24px 60px #000a" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "9px 14px", background: T.panel,
                borderBottom: `1px solid ${T.line}`, fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.dim }}>
                <span style={{ width: 9, height: 9, borderRadius: "50%", background: "#e0574b" }} />
                <span style={{ width: 9, height: 9, borderRadius: "50%", background: T.amber }} />
                <span style={{ width: 9, height: 9, borderRadius: "50%", background: T.green }} />
                <span style={{ marginLeft: 8 }}>v86 · i386 · FAT12 floppy · shell_monkey.img</span>
                <span style={{ marginLeft: "auto", color: statusColor }}>{statusLabel}</span>
              </div>
              <div style={{ position: "relative", display: "grid", placeItems: "center", aspectRatio: "4 / 3", background: "#000" }}>
                {live ? (
                  <window.V86Machine bootKey={bootKey} onStatus={onStatus} />
                ) : (
                  <div style={{ textAlign: "center", fontFamily: "'IBM Plex Mono', monospace" }}>
                    <div style={{ color: T.faint, fontSize: 13, marginBottom: 16 }}>floppy ready · shell + Monkey Island demo</div>
                    <button onClick={boot} style={{ background: T.pink, color: "#1a0f16", border: "none", borderRadius: 9,
                      padding: "13px 26px", fontFamily: "'Zen Kaku Gothic New', sans-serif", fontWeight: 700, fontSize: 16, cursor: "pointer" }}>
                      ▶ Power on
                    </button>
                  </div>
                )}
                {(phase === "booting" || phase === "stalled") && (
                  <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, padding: "6px 12px", background: "#000a",
                    fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: phase === "stalled" ? T.amber : T.green }}>
                    {phase === "stalled"
                      ? "still fetching BIOS + floppy… if this hangs, the image host may block cross-origin loads"
                      : "fetching v86.wasm + seabios + floppy…"}
                  </div>
                )}
                {phase === "error" && (
                  <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", padding: 24, background: "#000d",
                    textAlign: "center", fontFamily: "'IBM Plex Mono', monospace" }}>
                    <div>
                      <div style={{ color: "#e0574b", fontSize: 14, marginBottom: 8 }}>Couldn't start the machine</div>
                      <div style={{ color: T.dim, fontSize: 12, lineHeight: 1.6, maxWidth: 360 }}>{errMsg}</div>
                      <button onClick={boot} style={{ ...ctrlBtn(T), marginTop: 14 }}>↻ Try again</button>
                    </div>
                  </div>
                )}
                <div className="run-scan" style={{ position: "absolute", inset: 0, pointerEvents: "none" }} />
              </div>
            </div>
            <div style={{ display: "flex", gap: 8, marginTop: 12, flexWrap: "wrap" }}>
              <button onClick={boot} style={ctrlBtn(T)}>↻ Reboot</button>
              <button onClick={() => { const c = document.querySelector('.v86-screen canvas'); if (c && c.requestFullscreen) c.requestFullscreen(); }} style={ctrlBtn(T)}>⛶ Fullscreen</button>
              <a href={window.LAIN_IMG_URL} download style={{ ...ctrlBtn(T), textDecoration: "none" }}>⤓ Download .img</a>
              <span style={{ marginLeft: "auto", alignSelf: "center", fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.faint }}>
                click screen to type · Screen = VGA · Serial = COM1 log
              </span>
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <div>
              <h3 style={sectionH(T)}>Disk image</h3>
              <div style={{ border: `1px solid ${T.pink}`, borderRadius: 8, background: T.panel, padding: "12px 13px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: 9, fontFamily: "'Zen Kaku Gothic New', sans-serif",
                  fontSize: 14, color: T.ink, fontWeight: 600 }}>
                  <span style={{ width: 10, height: 10, borderRadius: "50%", background: T.pink }} /> shell_monkey.img
                  <span style={{ marginLeft: "auto", fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: T.faint }}>FAT12 · 1.44M</span>
                </div>
                <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.dim, lineHeight: 1.7, marginTop: 8 }}>
                  KERNEL.SYS · SHELL.COM<br />MIDEMO.EXE · MONKEY demo
                </div>
              </div>
            </div>
            <div>
              <h3 style={sectionH(T)}>Things to try</h3>
              <div style={{ display: "grid", gap: 10 }}>
                {window.RUN_TRIES.map(t => (
                  <div key={t.k} style={{ border: `1px solid ${T.line}`, borderRadius: 8, padding: "11px 13px", background: T.panel }}>
                    <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.amber, marginBottom: 4 }}>{t.k}</div>
                    <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13, color: T.dim, lineHeight: 1.5 }}><window.InlineText text={t.v} /></div>
                  </div>
                ))}
              </div>
            </div>
            <button onClick={() => go("boot")} style={ctaOutline(T.amber)}>← Re-read how it boots</button>
          </div>
        </div>
      </div>
    </div>
  );
}

function ctaOutline(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 9, padding: "13px 22px",
    fontFamily: "'Zen Kaku Gothic New', sans-serif", fontWeight: 600, fontSize: 15, cursor: "pointer" };
}
function ctrlBtn(T) {
  return { background: T.panel, color: T.ink, border: `1px solid ${T.line}`, borderRadius: 8, padding: "9px 14px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer" };
}
function sectionH(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 2, textTransform: "uppercase",
    color: T.dim, margin: "0 0 12px" };
}

Object.assign(window, { OverviewPage, StubPage, RunPage });
