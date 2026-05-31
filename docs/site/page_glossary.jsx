// page_glossary.jsx - glossary index for hover terms used throughout the site.

function GlossaryPage({ go }) {
  const T = window.T;
  const groups = glossaryGroups();
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Hover reference
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Glossary
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 760, margin: 0 }}>
            <window.InlineText text={"Underlined terms across the docs can be hovered or focused for the same short explanations collected here."} />
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 1120, margin: "0 auto", padding: "34px 56px 60px" }}>
        <div className="site-two-col" style={{ display: "grid", gridTemplateColumns: "1fr 300px", gap: 30, alignItems: "start" }}>
          <div>
            {groups.map(group => (
              <section key={group.category} style={glossaryCard(T)}>
                <h2 style={glossaryH2(T)}>{group.category}</h2>
                <div className="glossary-grid" style={{ display: "grid", gridTemplateColumns: "repeat(2, minmax(0, 1fr))", gap: 10, marginTop: 14 }}>
                  {group.terms.map(term => <GlossaryEntry key={term.term} term={term} />)}
                </div>
              </section>
            ))}
          </div>

          <aside className="site-boot-side" style={{ position: "sticky", top: 24 }}>
            <div style={glossaryPanel(T)}>
              <h3 style={glossaryKicker(T)}>How it works</h3>
              <p style={glossaryP(T)}>
                <window.InlineText text={"The same InlineText helper that renders `code spans` also recognizes glossary aliases outside code."} />
              </p>
              <p style={glossaryP(T)}>
                <window.InlineText text={"Hover with a pointer, or tab to a dotted-underlined term and focus it from the keyboard."} />
              </p>
              <button onClick={() => go("emulators")} style={glossaryButton(T.amber)}>Read emulator workflows</button>
            </div>
            <div style={{ ...glossaryPanel(T), marginTop: 14 }}>
              <h3 style={glossaryKicker(T)}>Term count</h3>
              <div style={{ fontFamily: "'Newsreader', serif", fontSize: 48, lineHeight: 1, color: T.pink }}>{window.GLOSSARY_TERMS.length}</div>
              <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.faint, marginTop: 6 }}>tracked terms</div>
            </div>
          </aside>
        </div>
      </div>
    </div>
  );
}

function glossaryGroups() {
  const groups = new Map();
  for (const term of window.GLOSSARY_TERMS.slice().sort((a, b) => a.term.localeCompare(b.term))) {
    if (!groups.has(term.category)) groups.set(term.category, []);
    groups.get(term.category).push(term);
  }
  return Array.from(groups.entries()).map(([category, terms]) => ({ category, terms }))
    .sort((a, b) => a.category.localeCompare(b.category));
}

function GlossaryEntry({ term }) {
  const T = window.T;
  return (
    <div style={{ border: `1px solid ${T.line}`, borderRadius: 9, background: "#fffdf6", padding: "11px 12px" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.pink, marginBottom: 5 }}>{term.term}</div>
      <div style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.2, color: T.dim, lineHeight: 1.48 }}>{term.definition}</div>
      {term.aliases.length > 1 && (
        <div style={{ display: "flex", gap: 5, flexWrap: "wrap", marginTop: 9 }}>
          {term.aliases.slice(1).map(alias => <code key={alias} style={glossaryAlias(T)}>{alias}</code>)}
        </div>
      )}
    </div>
  );
}

function glossaryCard(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "18px 20px", marginBottom: 22 };
}
function glossaryPanel(T) {
  return { border: `1px solid ${T.line}`, borderRadius: 12, background: T.panel, padding: "14px" };
}
function glossaryH2(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 25, lineHeight: 1.2, color: T.ink, margin: 0 };
}
function glossaryP(T) {
  return { fontFamily: "'Zen Kaku Gothic New', sans-serif", color: T.dim, fontSize: 14.5, lineHeight: 1.6, margin: "0 0 12px" };
}
function glossaryKicker(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.5, textTransform: "uppercase", color: T.dim, margin: "0 0 9px" };
}
function glossaryAlias(T) {
  return { fontFamily: "'IBM Plex Mono', monospace", fontSize: 10.8, color: T.blue, border: `1px solid ${T.line}`, borderRadius: 20, padding: "3px 7px", background: T.panel };
}
function glossaryButton(c) {
  return { background: "transparent", color: c, border: `1px solid ${c}`, borderRadius: 8, padding: "10px 13px",
    fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, cursor: "pointer", width: "100%" };
}

Object.assign(window, { GlossaryPage });
