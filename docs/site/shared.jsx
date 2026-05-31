// shared.jsx — small render helpers reused across pages.

// Render a single colored asm line as React spans (mnemonic / comment / label)
function AsmLine({ text, mono }) {
  const commentIdx = text.indexOf(";");
  let code = text, comment = "";
  if (commentIdx >= 0) { code = text.slice(0, commentIdx); comment = text.slice(commentIdx); }
  const mnem = code.match(/^(\s*)([a-z][a-z0-9]*)/i);
  const parts = [];
  if (mnem) {
    parts.push(<span key="i" style={{ whiteSpace: "pre" }}>{mnem[1]}</span>);
    parts.push(<span key="m" style={{ color: mono.mnem, fontWeight: 600 }}>{mnem[2]}</span>);
    parts.push(<span key="r" style={{ color: mono.text }}>{code.slice(mnem[0].length)}</span>);
  } else {
    parts.push(<span key="c" style={{ color: code.endsWith(":") ? mono.label : mono.text }}>{code}</span>);
  }
  if (comment) parts.push(<span key="cm" style={{ color: mono.comment, fontStyle: "italic" }}>{comment}</span>);
  return <span>{parts}</span>;
}

function InlineText({ text }) {
  if (typeof text !== "string") return text;
  const parts = [];
  let pos = 0;
  let key = 0;
  while (pos < text.length) {
    const start = text.indexOf("`", pos);
    if (start < 0) {
      parts.push(text.slice(pos));
      break;
    }
    const end = text.indexOf("`", start + 1);
    if (end < 0) {
      parts.push(text.slice(pos));
      break;
    }
    if (start > pos) parts.push(text.slice(pos, start));
    parts.push(<code key={key++} style={inlineCodeStyle()}>{text.slice(start + 1, end)}</code>);
    pos = end + 1;
  }
  return <>{parts}</>;
}

function inlineCodeStyle() {
  const T = window.T || {};
  return {
    fontFamily: "'IBM Plex Mono', monospace",
    fontSize: "0.88em",
    color: T.ink || "#403626",
    background: "rgba(255,250,240,0.72)",
    border: `1px solid ${T.line || "#e6dac4"}`,
    borderRadius: 4,
    padding: "0 3px",
    whiteSpace: "pre-wrap",
  };
}

Object.assign(window, { AsmLine, InlineText });
