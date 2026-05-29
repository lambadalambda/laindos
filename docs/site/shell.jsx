// shell.jsx — theme, layout shell, sidebar nav, memory map, code block.
// Cream / editorial palette with a dark terminal-style code block.
const T = {
  bg: "#f7f1e6", panel: "#fffaf0", panel2: "#efe6d6", ink: "#403626", dim: "#8a7d64",
  faint: "#a89a80", line: "#e6dac4",
  amber: "#c25a6e",
  green: "#3f8f96",
  pink:  "#c2497f",
  blue:  "#3f7f96",
};
const CODE = { mnem: "#ff9ad4", text: "#e7ddf0", comment: "#897ba0", label: "#7ee0d4" };
const CODE_BG = "#241b2e", CODE_HEAD = "#2c2238", CODE_LINE = "rgba(255,255,255,0.07)",
  CODE_NUM = "#5b4f73", CODE_DIM = "#9a8cb0";

function StatusDot({ status }) {
  const map = { done: T.green, wip: T.amber, soon: T.faint };
  const label = { done: "complete", wip: "in progress", soon: "planned" }[status];
  return (
    <span title={label} style={{ width: 8, height: 8, borderRadius: "50%", background: map[status] || T.faint,
      boxShadow: status === "wip" ? `0 0 7px ${T.amber}66` : "none", flex: "0 0 auto" }} />
  );
}

function Sidebar({ route, go }) {
  const [stage] = route.split("/");
  return (
    <aside className="site-sidebar" style={{ width: 282, borderRight: `1px solid ${T.line}`, background: "#f1e7d6",
      height: "100vh", position: "fixed", left: 0, top: 0, overflowY: "auto", padding: "22px 0", zIndex: 50 }}>
      <div onClick={() => go("overview")} style={{ display: "flex", alignItems: "center", gap: 11, padding: "0 22px 20px", cursor: "pointer" }}>
        <div style={{ width: 32, height: 32, borderRadius: 7, background: T.ink, color: "#f7f1e6", display: "grid",
          placeItems: "center", fontFamily: "'Newsreader', serif", fontSize: 22, lineHeight: "32px" }}>л</div>
        <div>
          <div style={{ fontFamily: "'Newsreader', serif", fontSize: 23, lineHeight: "26px", color: T.ink, letterSpacing: 0.3, fontWeight: 600 }}>LainDOS</div>
          <div style={{ fontSize: 10.5, color: T.dim, fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 1 }}>source, annotated</div>
        </div>
      </div>

      <nav style={{ fontFamily: "'IBM Plex Mono', monospace" }}>
        {window.NAV.map((item) => {
          const active = stage === item.id;
          if (item.kind === "run") {
            return (
              <div key={item.id} style={{ margin: "14px 16px 0", paddingTop: 14, borderTop: `1px solid ${T.line}` }}>
                <button onClick={() => go("run")} style={{
                  width: "100%", display: "flex", alignItems: "center", gap: 9, padding: "11px 12px", cursor: "pointer",
                  background: active ? T.pink : "transparent", color: active ? "#fff" : T.pink,
                  border: `1px solid ${T.pink}`, borderRadius: 8, fontSize: 13.5, fontWeight: 600, fontFamily: "inherit" }}>
                  <span style={{ fontSize: 13 }}>▶</span> Run it — the emulator
                </button>
              </div>
            );
          }
          if (item.kind === "page") {
            return (
              <a key={item.id} onClick={() => go(item.id)} style={navItem(active)}>
                <span style={{ width: 8 }} />{item.label}
              </a>
            );
          }
          return (
            <div key={item.id} style={{ marginTop: 4 }}>
              <a onClick={() => go(item.id)} style={{ ...navItem(active), justifyContent: "space-between" }}>
                <span style={{ display: "flex", alignItems: "center", gap: 9 }}>
                  <StatusDot status={item.status} /> {item.label}
                </span>
              </a>
              {active && item.children && (
                <div style={{ margin: "2px 0 8px" }}>
                  {item.children.map(([cid, clabel], i) => (
                    <a key={cid} onClick={() => go(`${item.id}/${cid}`)} style={{
                      display: "block", padding: "5px 22px 5px 50px", fontSize: 12, cursor: "pointer",
                      color: route === `${item.id}/${cid}` ? T.amber : T.dim, lineHeight: 1.4,
                      borderLeft: route === `${item.id}/${cid}` ? `2px solid ${T.amber}` : "2px solid transparent" }}>
                      <span style={{ color: T.faint }}>{String(i).padStart(2, "0")}</span>  {clabel}
                    </a>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </nav>

      <div style={{ padding: "20px 22px 0", color: T.faint, fontSize: 10.5, fontFamily: "'IBM Plex Mono', monospace", lineHeight: 1.7 }}>
        single-tasking · real mode<br />NASM · CC0 · 67/67 tests
      </div>
    </aside>
  );
}
function navItem(active) {
  return {
    display: "flex", alignItems: "center", gap: 9, padding: "9px 22px", cursor: "pointer", fontSize: 13.5,
    color: active ? T.ink : T.dim, background: active ? "rgba(194,90,126,0.10)" : "transparent",
    borderLeft: active ? `2px solid ${T.amber}` : "2px solid transparent", textDecoration: "none",
  };
}

function MemoryMap({ touches = [], compact = false }) {
  const on = new Set(touches);
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 9, overflow: "hidden", background: T.panel }}>
      <div style={{ padding: "9px 13px", borderBottom: `1px solid ${T.line}`, display: "flex", alignItems: "center",
        fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, color: T.dim, textTransform: "uppercase" }}>
        Low memory <span style={{ marginLeft: "auto", color: T.faint }}>seg:0</span>
      </div>
      <div>
        {window.MEMMAP.map((m) => {
          const lit = on.has(m.key);
          return (
            <div key={m.seg} style={{ display: "flex", gap: 10, padding: compact ? "6px 13px" : "9px 13px",
              borderBottom: `1px solid ${T.line}`, background: lit ? "rgba(194,90,126,0.10)" : "transparent",
              boxShadow: lit ? `inset 3px 0 0 ${T.amber}` : "none", transition: "background .2s" }}>
              <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: lit ? T.amber : T.faint,
                width: 46, flex: "0 0 auto" }}>{m.seg}</code>
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: 12.5, color: lit ? T.ink : T.dim, fontFamily: "'Zen Kaku Gothic New', sans-serif",
                  whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                  {m.name}{m.grow && <span style={{ color: T.faint, fontSize: 11 }}> ↕</span>}
                </div>
                {!compact && <div style={{ fontSize: 10.5, color: T.faint, fontFamily: "'IBM Plex Mono', monospace" }}>{m.note}</div>}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function CodeBlock({ file, code, hi = [] }) {
  const hiSet = new Set(hi);
  return (
    <div style={{ background: CODE_BG, border: `1px solid ${CODE_LINE}`, borderRadius: 9, overflow: "hidden",
      boxShadow: "0 8px 24px rgba(40,28,52,0.14)" }}>
      {file && (
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 13px", borderBottom: `1px solid ${CODE_LINE}`,
          fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: CODE_DIM, background: CODE_HEAD }}>
          <span style={{ color: CODE.label }}>›</span>{file}
          <span style={{ marginLeft: "auto", color: CODE_NUM }}>NASM · 16-bit</span>
        </div>
      )}
      <div style={{ display: "flex", fontFamily: "'IBM Plex Mono', monospace", fontSize: 13, lineHeight: "22px", padding: "10px 0" }}>
        <div style={{ color: CODE_NUM, textAlign: "right", padding: "0 12px", userSelect: "none", flex: "0 0 auto" }}>
          {code.map((l, i) => <div key={i}>{l[0] === "" ? " " : l[0]}</div>)}
        </div>
        <div style={{ padding: "0 14px 0 0", whiteSpace: "pre", flex: 1, overflowX: "auto" }}>
          {code.map((l, i) => (
            <div key={i} style={{ background: hiSet.has(l[0]) ? "rgba(255,154,212,0.13)" : "transparent",
              boxShadow: hiSet.has(l[0]) ? `inset 2px 0 0 ${CODE.mnem}` : "none",
              paddingLeft: 12, marginLeft: -12 }}>
              {l[1] === "" ? " " : <window.AsmLine text={l[1]} mono={CODE} />}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function RegPanel({ regs }) {
  if (!regs || !regs.length) return null;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 9, overflow: "hidden", background: T.panel }}>
      <div style={{ padding: "8px 13px", borderBottom: `1px solid ${T.line}`,
        fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, color: T.dim, textTransform: "uppercase" }}>
        Registers & state after
      </div>
      <div>
        {regs.map((r, i) => (
          <div key={i} style={{ display: "flex", gap: 10, padding: "8px 13px",
            borderBottom: i < regs.length - 1 ? `1px solid ${T.line}` : "none", alignItems: "baseline" }}>
            <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.blue,
              width: 92, flex: "0 0 auto" }}>{r[0]}</code>
            <code style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: T.amber,
              width: 70, flex: "0 0 auto", fontWeight: 600 }}>{r[1]}</code>
            <span style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 11.5, color: T.dim, lineHeight: 1.4 }}>{r[2]}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { T, CODE, Sidebar, MemoryMap, CodeBlock, StatusDot, RegPanel });
