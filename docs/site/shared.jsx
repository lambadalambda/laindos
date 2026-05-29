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

Object.assign(window, { AsmLine });
