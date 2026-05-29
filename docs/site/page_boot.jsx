// page_boot.jsx — the Boot Path walkthrough (the narrative spine).
function BootPage({ scrollReq, onActive, go }) {
  const T = window.T;
  const stages = window.STAGES;
  const [active, setActive] = React.useState("s0");
  const lockRef = React.useRef(false);

  const navOf = (id) => (id === "s1b" ? "s1" : id);

  React.useEffect(() => {
    if (!scrollReq || !scrollReq.id) return;
    const el = document.querySelector(`[data-stage="${scrollReq.id}"]`);
    if (!el) return;
    lockRef.current = true;
    const top = el.getBoundingClientRect().top + window.scrollY - 18;
    window.scrollTo({ top, behavior: "auto" });
    const t = setTimeout(() => { lockRef.current = false; }, 700);
    return () => clearTimeout(t);
  }, [scrollReq]);

  React.useEffect(() => {
    const obs = new IntersectionObserver((entries) => {
      if (lockRef.current) return;
      const vis = entries.filter(e => e.isIntersecting)
        .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (vis) {
        const id = vis.target.getAttribute("data-stage");
        setActive(id);
        onActive(navOf(id));
      }
    }, { root: null, rootMargin: "-40% 0px -45% 0px", threshold: [0, 0.5, 1] });
    document.querySelectorAll("[data-stage]").forEach(el => obs.observe(el));
    return () => obs.disconnect();
  }, [onActive]);

  const cur = stages.find(s => s.id === active) || stages[0];
  const idx = stages.findIndex(s => s.id === active);

  return (
    <div style={{ background: T.bg, minHeight: "100vh" }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px", position: "relative" }}>
        <div style={{ maxWidth: 1180, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Track 01 · complete
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            The Boot Path
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 640, margin: 0 }}>
            Follow LainDOS from the reset vector to a running game — eight steps, each with the real
            source that does the work and a live view of the memory it touches. Scroll, or jump to any step.
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1180, margin: "0 auto", padding: "22px 56px 0" }}>
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
          {stages.map((s) => {
            const on = s.id === active;
            return (
              <button key={s.id} onClick={() => go(`boot/${s.id}`)} title={s.title} style={{
                display: "flex", alignItems: "center", gap: 7, padding: "6px 11px", cursor: "pointer",
                borderRadius: 20, fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5,
                border: `1px solid ${on ? (s.payoff ? T.pink : T.amber) : T.line}`,
                color: on ? (s.payoff ? T.pink : T.amber) : T.dim, background: on ? "rgba(194,90,126,0.10)" : T.panel }}>
                <span style={{ width: 6, height: 6, borderRadius: "50%",
                  background: s.payoff ? T.pink : (on ? T.amber : T.faint) }} />
                {s.num}
              </button>
            );
          })}
        </div>
      </div>

      <div className="site-boot-layout" style={{ display: "flex", gap: 40, alignItems: "flex-start", maxWidth: 1180, margin: "0 auto", padding: "0 56px 40px" }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          {stages.map((s) => (
            <section key={s.id} data-stage={s.id} data-screen-label={`Boot ${s.num}`}
              style={{ padding: "28px 0 40px", borderTop: `1px solid ${T.line}` }}>
              <div style={{ display: "flex", alignItems: "flex-start", gap: 16, marginBottom: 16 }}>
                <span style={{ fontFamily: "'Newsreader', serif", fontSize: 50, lineHeight: 1, width: 56,
                  flex: "0 0 auto", marginTop: 2, color: s.payoff ? T.pink : T.amber }}>{s.num}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 2,
                    textTransform: "uppercase", color: T.faint }}>{s.kicker}</div>
                  <h2 style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontWeight: 600, fontSize: 24,
                    color: T.ink, margin: "4px 0 0", letterSpacing: -.3, lineHeight: 1.25 }}>{s.title}</h2>
                </div>
              </div>
              {s.prose.map((p, i) => (
                <p key={i} style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 15.5,
                  lineHeight: 1.7, maxWidth: 600, margin: "0 0 14px" }}>{p}</p>
              ))}
              {s.code && <div style={{ margin: "18px 0 14px" }}><window.CodeBlock file={s.file} code={s.code} hi={s.hi} /></div>}
              {s.annotations && s.annotations.length > 0 && (
                <div style={{ margin: "16px 0 16px", display: "grid", gap: 11 }}>
                  {s.annotations.map((a, i) => (
                    <div key={i} style={{ display: "flex", gap: 12, alignItems: "baseline" }}>
                      <code style={{ flex: "0 0 auto", fontFamily: "'IBM Plex Mono', monospace", fontSize: 11,
                        color: T.amber, border: `1px solid ${T.line}`, borderRadius: 5, padding: "2px 7px",
                        minWidth: 46, textAlign: "center", background: T.panel }}>
                        {a[0]}
                      </code>
                      <p style={{ margin: 0, fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 14.5,
                        lineHeight: 1.6, color: T.dim, maxWidth: 600 }}>{a[1]}</p>
                    </div>
                  ))}
                </div>
              )}
              {s.note && (
                <div style={{ display: "inline-flex", alignItems: "center", gap: 9, fontFamily: "'IBM Plex Mono', monospace",
                  fontSize: 12, color: s.payoff ? T.pink : T.green, border: `1px solid ${T.line}`, borderRadius: 7,
                  padding: "7px 12px", background: T.panel }}>
                  <span style={{ color: T.faint }}>state →</span> {s.note}
                </div>
              )}
              {s.payoff && (
                <div style={{ marginTop: 24 }}>
                  <button onClick={() => go("run")} style={{ display: "inline-flex", alignItems: "center", gap: 10,
                    background: T.pink, color: "#1a0f16", border: "none", borderRadius: 9, padding: "13px 20px",
                    fontFamily: "'Zen Kaku Gothic New', sans-serif", fontWeight: 600, fontSize: 15, cursor: "pointer" }}>
                    ▶ Now boot it yourself
                  </button>
                </div>
              )}
            </section>
          ))}
        </div>

        <div className="site-boot-side" style={{ width: 320, flex: "0 0 320px", position: "sticky", top: 24, alignSelf: "flex-start" }}>
          <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5,
            textTransform: "uppercase", color: T.dim, marginBottom: 10, display: "flex", alignItems: "center",
            gap: 8, whiteSpace: "nowrap" }}>
            Memory · step {cur.num}
            <span style={{ marginLeft: "auto", color: T.faint }}>{idx + 1}/{stages.length}</span>
          </div>
          <window.MemoryMap touches={cur.touches} compact />
          <div style={{ marginTop: 12 }}><window.RegPanel regs={cur.regs} /></div>
          <div style={{ marginTop: 12, border: `1px solid ${T.line}`, borderRadius: 9, background: T.panel,
            padding: "11px 13px", fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.dim, lineHeight: 1.6 }}>
            <span style={{ color: T.faint }}>highlighted:</span> the segments this step reads or writes.
            <div style={{ marginTop: 8, color: cur.payoff ? T.pink : T.amber }}>{cur.note}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
window.BootPage = BootPage;
