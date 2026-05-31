#!/usr/bin/env -S deno run --allow-read --allow-write --allow-run=deno

const APP_SRC = new URL("../docs/site/app.jsx", import.meta.url);

const VOID_TAGS = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"]);
const UNITLESS_STYLE = new Set([
  "animationIterationCount", "borderImageOutset", "borderImageSlice", "borderImageWidth", "boxFlex",
  "boxFlexGroup", "boxOrdinalGroup", "columnCount", "columns", "flex", "flexGrow", "flexPositive",
  "flexShrink", "flexNegative", "flexOrder", "gridArea", "gridRow", "gridRowEnd", "gridRowSpan",
  "gridRowStart", "gridColumn", "gridColumnEnd", "gridColumnSpan", "gridColumnStart", "fontWeight",
  "lineClamp", "lineHeight", "opacity", "order", "orphans", "tabSize", "widows", "zIndex", "zoom",
]);

function usage() {
  console.error("usage: deno run --allow-read --allow-write --allow-run=deno scripts/build_site.jsx --out build/site [--image build/shell_monkey.img]");
}

function parseArgs(args) {
  const opts = { out: "build/site", image: "" };
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (arg === "--out") opts.out = args[++i];
    else if (arg === "--image") opts.image = args[++i];
    else {
      usage();
      Deno.exit(2);
    }
  }
  return opts;
}

function flatten(items, out = []) {
  for (const item of items) {
    if (Array.isArray(item)) flatten(item, out);
    else out.push(item);
  }
  return out;
}

const fakeReact = {
  Fragment: Symbol("Fragment"),
  createElement(type, props, ...children) {
    return { type, props: { ...(props || {}), children: flatten(children) } };
  },
  useState(initial) {
    return [typeof initial === "function" ? initial() : initial, () => {}];
  },
  useRef(initial) {
    return { current: initial };
  },
  useEffect() {},
  useCallback(fn) {
    return fn;
  },
};

globalThis.React = fakeReact;
globalThis.window = globalThis;

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function styleName(name) {
  if (name.startsWith("--")) return name;
  return name.replace(/[A-Z]/g, ch => `-${ch.toLowerCase()}`);
}

function styleValue(name, value) {
  if (typeof value === "number" && value !== 0 && !UNITLESS_STYLE.has(name)) return `${value}px`;
  return String(value);
}

function renderStyle(style) {
  return Object.entries(style)
    .filter(([, value]) => value !== null && value !== undefined && value !== false)
    .map(([name, value]) => `${styleName(name)}:${styleValue(name, value)}`)
    .join(";");
}

function renderAttrs(props) {
  const attrs = [];
  for (const [name, value] of Object.entries(props || {})) {
    if (name === "children" || name === "key" || name === "ref" || name.startsWith("on")) continue;
    if (value === null || value === undefined || value === false) continue;
    const attr = name === "className" ? "class" : name === "htmlFor" ? "for" : name;
    if (attr === "style" && typeof value === "object") {
      const css = renderStyle(value);
      if (css) attrs.push(`style="${escapeHtml(css)}"`);
    } else if (value === true) {
      attrs.push(attr);
    } else {
      attrs.push(`${attr}="${escapeHtml(value)}"`);
    }
  }
  return attrs.length ? ` ${attrs.join(" ")}` : "";
}

function renderNode(node) {
  if (node === null || node === undefined || node === false || node === true) return "";
  if (typeof node === "string" || typeof node === "number") return escapeHtml(node);
  if (Array.isArray(node)) return node.map(renderNode).join("");
  if (typeof node.type === "function") return renderNode(node.type(node.props || {}));
  const props = node.props || {};
  const children = props.children || [];
  if (node.type === fakeReact.Fragment) return renderNode(children);
  const tag = node.type;
  const attrs = renderAttrs(props);
  if (VOID_TAGS.has(tag)) return `<${tag}${attrs}>`;
  return `<${tag}${attrs}>${renderNode(children)}</${tag}>`;
}

function siteCss() {
  return `
  html, body { margin: 0; padding: 0; background: #f7f1e6; }
  * { box-sizing: border-box; }
  ::-webkit-scrollbar { width: 10px; height: 10px; }
  ::-webkit-scrollbar-thumb { background: #d8c9ad; border-radius: 6px; }
  ::-webkit-scrollbar-track { background: transparent; }
  body { scrollbar-color: #d8c9ad transparent; }
  .run-scan {
    background: repeating-linear-gradient(to bottom,
      rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.18) 3px, rgba(0,0,0,0.18) 4px);
    opacity: .5;
  }
  .hero-bg {
    background:
      radial-gradient(1200px 600px at 18% 18%, rgba(255, 225, 192, 0.35), transparent 60%),
      radial-gradient(900px 600px at 88% 80%, rgba(126, 224, 212, 0.25), transparent 65%),
      linear-gradient(135deg, #2a1d3a 0%, #3a2230 45%, #5a334b 100%);
  }
  .v86-screen { color: #e9e7da; overflow: hidden; }
  .v86-screen > div { white-space: pre; font: 15px/1.04 'IBM Plex Mono', monospace; }
  .v86-screen > div, .v86-screen canvas { flex: 0 0 auto; transform-origin: center center; }
  .v86-screen canvas { image-rendering: pixelated; max-width: 100%; max-height: 100%; }
  .v86-term {
    white-space: pre-wrap; word-break: break-word;
    font: 14px/1.45 'IBM Plex Mono', monospace;
    color: #8ef0a8; background: #000; caret-color: #8ef0a8;
  }
  .v86-term:focus { box-shadow: inset 0 0 0 1px #2a6a3a; }
  .glossary-term {
    position: relative;
    display: inline-block;
    color: inherit;
    text-decoration: underline dotted #c25a6e 1px;
    text-underline-offset: 3px;
    cursor: help;
  }
  .glossary-term:focus { outline: 1px solid #c25a6e; outline-offset: 2px; border-radius: 3px; }
  .glossary-popover {
    position: absolute;
    left: 0;
    bottom: calc(100% + 8px);
    z-index: 80;
    width: min(280px, 72vw);
    padding: 10px 12px;
    border: 1px solid #e6dac4;
    border-radius: 8px;
    background: #fffaf0;
    box-shadow: 0 14px 36px rgba(64,54,38,0.18);
    color: #8a7d64;
    font: 12.5px/1.45 'Zen Kaku Gothic New', sans-serif;
    text-align: left;
    visibility: hidden;
    opacity: 0;
    transform: translateY(4px);
    transition: opacity .12s ease, transform .12s ease, visibility .12s ease;
    pointer-events: none;
  }
  .glossary-popover::after {
    content: "";
    position: absolute;
    left: 14px;
    bottom: -6px;
    width: 10px;
    height: 10px;
    background: #fffaf0;
    border-right: 1px solid #e6dac4;
    border-bottom: 1px solid #e6dac4;
    transform: rotate(45deg);
  }
  .glossary-popover-title {
    display: block;
    margin-bottom: 4px;
    color: #c25a6e;
    font: 600 11px/1.2 'IBM Plex Mono', monospace;
    letter-spacing: .5px;
    text-transform: uppercase;
  }
  .glossary-term:hover .glossary-popover,
  .glossary-term:focus .glossary-popover,
  .glossary-term:focus-within .glossary-popover {
    visibility: visible;
    opacity: 1;
    transform: translateY(0);
  }
  @media (max-width: 860px) {
    .site-sidebar { position: static !important; width: 100% !important; height: auto !important; border-right: 0 !important; border-bottom: 1px solid #e6dac4 !important; }
    .site-main { margin-left: 0 !important; }
    .site-two-col, .site-run-grid, .site-boot-layout { display: block !important; }
    .site-boot-side { position: static !important; width: auto !important; margin-top: 18px; }
    .site-main header, .site-main > div > div { padding-left: 22px !important; padding-right: 22px !important; }
    .site-main h1 { font-size: 52px !important; line-height: 56px !important; }
    .dosapi-call-row { grid-template-columns: 44px 1fr !important; }
    .dosapi-call-row > div:last-child { grid-column: 1 / -1; }
    .dosapi-sub-row { grid-template-columns: 1fr !important; }
    .dosapi-stat-grid { grid-template-columns: 1fr !important; }
    .emulator-target-row { grid-template-columns: 1fr !important; }
    .emulator-probe-grid, .glossary-grid { grid-template-columns: 1fr !important; }
  }`;
}

function htmlForPage(page, body, imageUrl) {
  const config = `window.LAIN_PAGE=${JSON.stringify(page.route)};window.LAIN_IMG_URL=${JSON.stringify(imageUrl)};`;
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>${escapeHtml(page.title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=Newsreader:ital,opsz,wght@0,6..72,400;0,6..72,500;0,6..72,600;1,6..72,400&family=IBM+Plex+Mono:ital,wght@0,400;0,500;0,600;1,400&family=Zen+Kaku+Gothic+New:wght@400;500;700&display=swap" rel="stylesheet" />
<style>${siteCss()}</style>
</head>
<body>
<noscript><div style="padding:10px 14px;font:13px 'IBM Plex Mono',monospace;background:#fffaf0;color:#8a7d64;border-bottom:1px solid #e6dac4">Static documentation is readable without JavaScript; navigation buttons and the emulator need JavaScript.</div></noscript>
<div id="root">${body}</div>
<script>${config}</script>
<script src="https://unpkg.com/react@18.3.1/umd/react.production.min.js" crossorigin="anonymous"></script>
<script src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js" crossorigin="anonymous"></script>
<script src="https://cdn.jsdelivr.net/npm/v86@0.5.359%2Bge37189a/build/libv86.js"></script>
<script src="app.js"></script>
</body>
</html>
`;
}

async function hashFile(path) {
  const data = await Deno.readFile(path);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("");
}

async function runBundle(outDir) {
  const appOut = `${outDir}/app.js`;
  const command = new Deno.Command(Deno.execPath(), {
    args: ["bundle", "--format", "iife", "--platform", "browser", "--minify", "--output", appOut, APP_SRC.pathname],
    cwd: new URL("..", import.meta.url).pathname,
  });
  const result = await command.output();
  await Deno.stdout.write(result.stdout);
  await Deno.stderr.write(result.stderr);
  if (!result.success) Deno.exit(result.code);
}

async function copyIfImage(image, outDir) {
  if (!image) return "shell_monkey.img";
  const stat = await Deno.stat(image).catch(() => null);
  if (!stat || !stat.isFile) throw new Error(`site image missing: ${image}`);
  await Deno.copyFile(image, `${outDir}/shell_monkey.img`);
  const hash = await hashFile(image);
  return `shell_monkey.img?v=${hash.slice(0, 16)}`;
}

async function main() {
  const opts = parseArgs(Deno.args);
  const outDir = opts.out;
  await Deno.remove(outDir, { recursive: true }).catch(() => {});
  await Deno.mkdir(outDir, { recursive: true });
  const imageUrl = await copyIfImage(opts.image, outDir);
  globalThis.LAIN_IMG_URL = imageUrl;

  const { App, SITE_PAGES } = await import(APP_SRC.href);
  for (const page of SITE_PAGES) {
    const body = renderNode(fakeReact.createElement(App, { initialRoute: page.route }));
    await Deno.writeTextFile(`${outDir}/${page.file}`, htmlForPage(page, body, imageUrl));
  }
  await runBundle(outDir);
  await Deno.writeTextFile(`${outDir}/.nojekyll`, "");

  for (const page of SITE_PAGES) await Deno.stat(`${outDir}/${page.file}`);
  await Deno.stat(`${outDir}/app.js`);
  if (opts.image) await Deno.stat(`${outDir}/shell_monkey.img`);
  console.log(`Built static site in ${outDir} (${SITE_PAGES.length} pages).`);
}

if (import.meta.main) main();
