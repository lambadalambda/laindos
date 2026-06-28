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
const SOURCE_URL = "https://github.com/lambadalambda/laindos";

function StatusDot({ status }) {
  const map = { done: T.green, wip: T.amber, soon: T.faint };
  const label = { done: "complete", wip: "in progress", soon: "planned" }[status];
  return (
    <span title={label} style={{ width: 8, height: 8, borderRadius: "50%", background: map[status] || T.faint,
      boxShadow: status === "wip" ? `0 0 7px ${T.amber}66` : "none", flex: "0 0 auto" }} />
  );
}

function sidebarHrefFor(target) {
  const [route, ...rest] = String(target || "overview").split("/");
  const aliases = { index: "overview", filesystem: "fs", memory: "mem", programs: "prog" };
  const pageRoute = aliases[route] || route;
  const files = { overview: "index.html", boot: "boot.html", dosapi: "dosapi.html", tests: "tests.html", fs: "filesystem.html", mem: "memory.html", prog: "programs.html", shell: "shell.html", mouse: "mouse.html", emulators: "emulators.html", glossary: "glossary.html", run: "run.html" };
  return `${files[pageRoute] || "index.html"}${rest.length ? `#${encodeURIComponent(rest.join("/"))}` : ""}`;
}

function Sidebar({ route, go, hrefFor = sidebarHrefFor }) {
  const [stage] = route.split("/");
  const navClick = (target) => (event) => {
    event.preventDefault();
    go(target);
  };
  return (
    <aside className="site-sidebar" style={{ width: 282, borderRight: `1px solid ${T.line}`, background: "#f1e7d6",
      height: "100vh", position: "fixed", left: 0, top: 0, overflowY: "auto", padding: "22px 0", zIndex: 50 }}>
      <a href={hrefFor("overview")} onClick={navClick("overview")} style={{ display: "flex", alignItems: "center", gap: 11, padding: "0 22px 20px", cursor: "pointer", textDecoration: "none" }}>
        <div style={{ width: 32, height: 32, borderRadius: 7, background: T.ink, color: "#f7f1e6", display: "grid",
          placeItems: "center", fontFamily: "'Newsreader', serif", fontSize: 22, lineHeight: "32px" }}>л</div>
        <div>
          <div style={{ fontFamily: "'Newsreader', serif", fontSize: 23, lineHeight: "26px", color: T.ink, letterSpacing: 0.3, fontWeight: 600 }}>LainDOS</div>
          <div style={{ fontSize: 10.5, color: T.dim, fontFamily: "'IBM Plex Mono', monospace", letterSpacing: 1 }}>source, annotated</div>
        </div>
      </a>

      <a href={SOURCE_URL} target="_blank" rel="noreferrer" style={{
        display: "block", margin: "0 16px 18px", padding: "12px 13px", borderRadius: 10,
        background: T.ink, color: "#fffaf0", textDecoration: "none", boxShadow: "0 10px 24px rgba(64,54,38,0.16)",
        fontFamily: "'IBM Plex Mono', monospace" }}>
        <div style={{ fontSize: 10, letterSpacing: 1.6, textTransform: "uppercase", color: "#ffe1c0" }}>Source code</div>
        <div style={{ marginTop: 4, fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 15, fontWeight: 700 }}>View Actual Source</div>
        <div style={{ marginTop: 3, fontSize: 10.5, color: "#d8c9ad", wordBreak: "break-word" }}>github.com/lambadalambda/laindos ↗</div>
      </a>

      <nav style={{ fontFamily: "'IBM Plex Mono', monospace" }}>
        {window.NAV.map((item) => {
          const active = stage === item.id;
          if (item.kind === "run") {
            return (
              <div key={item.id} style={{ margin: "14px 16px 0", paddingTop: 14, borderTop: `1px solid ${T.line}` }}>
                <a href={hrefFor("run")} onClick={navClick("run")} style={{
                  width: "100%", display: "flex", alignItems: "center", gap: 9, padding: "11px 12px", cursor: "pointer",
                  background: active ? T.pink : "transparent", color: active ? "#fff" : T.pink,
                  border: `1px solid ${T.pink}`, borderRadius: 8, fontSize: 13.5, fontWeight: 600, fontFamily: "inherit", textDecoration: "none" }}>
                  <span style={{ fontSize: 13 }}>▶</span> Run it — the emulator
                </a>
              </div>
            );
          }
          if (item.kind === "page") {
            return (
              <a key={item.id} href={hrefFor(item.id)} onClick={navClick(item.id)} style={navItem(active)}>
                <span style={{ width: 8 }} />{item.label}
              </a>
            );
          }
          return (
            <div key={item.id} style={{ marginTop: 4 }}>
              <a href={hrefFor(item.id)} onClick={navClick(item.id)} style={{ ...navItem(active), justifyContent: "space-between" }}>
                <span style={{ display: "flex", alignItems: "center", gap: 9 }}>
                  <StatusDot status={item.status} /> {item.label}
                </span>
              </a>
              {active && item.children && (
                <div style={{ margin: "2px 0 8px" }}>
                  {item.children.map(([cid, clabel], i) => (
                    <a key={cid} href={hrefFor(`${item.id}/${cid}`)} onClick={navClick(`${item.id}/${cid}`)} style={{
                      display: "block", padding: "5px 22px 5px 50px", fontSize: 12, cursor: "pointer",
                      textDecoration: "none",
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
        single-tasking · real mode<br />NASM · CC0 · 171/171 tests
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

function codeLineId(value) {
  if (value && typeof value === "object" && value.a) return value.a;
  return value;
}
function codeLineLabel(value) {
  const id = codeLineId(value);
  if (id === null || id === undefined) return " ";
  return id === "" ? " " : String(id);
}
function CodeBlock({ file, code, hi = [], kind = "NASM · 16-bit" }) {
  const hiSet = new Set(hi.map(codeLineId));
  return (
    <div style={{ background: CODE_BG, border: `1px solid ${CODE_LINE}`, borderRadius: 9, overflow: "hidden", minWidth: 0,
      boxShadow: "0 8px 24px rgba(40,28,52,0.14)" }}>
      {file && (
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 13px", borderBottom: `1px solid ${CODE_LINE}`,
          fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: CODE_DIM, background: CODE_HEAD }}>
          <span style={{ color: CODE.label }}>›</span>{file}
          <span style={{ marginLeft: "auto", color: CODE_NUM }}>{kind}</span>
        </div>
      )}
      <div style={{ display: "flex", fontFamily: "'IBM Plex Mono', monospace", fontSize: 13, lineHeight: "22px", padding: "10px 0", minWidth: 0 }}>
        <div style={{ color: CODE_NUM, textAlign: "right", padding: "0 12px", userSelect: "none", flex: "0 0 auto" }}>
          {code.map((l, i) => <div key={i}>{codeLineLabel(l[0])}</div>)}
        </div>
        <div style={{ padding: "0 14px 0 0", whiteSpace: "pre", flex: 1, minWidth: 0, overflowX: "auto" }}>
          {code.map((l, i) => {
            const highlighted = hiSet.has(codeLineId(l[0]));
            return <div key={i} style={{ background: highlighted ? "rgba(255,154,212,0.13)" : "transparent",
              boxShadow: highlighted ? `inset 2px 0 0 ${CODE.mnem}` : "none",
              paddingLeft: 12, marginLeft: -12 }}>
              {l[1] === "" ? " " : <window.AsmLine text={l[1]} mono={CODE} />}
            </div>;
          })}
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
