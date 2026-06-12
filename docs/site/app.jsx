// app.jsx - static-page entry point for the LainDOS documentation site.

import "./shared.jsx";
import "./data.jsx";
import "./shell.jsx";
import "./v86machine.jsx";
import "./page_boot.jsx";
import "./page_misc.jsx";
import "./page_dosapi.jsx";
import "./page_tests.jsx";
import "./page_filesystem.jsx";
import "./page_memory.jsx";
import "./page_programs.jsx";
import "./page_shell.jsx";
import "./page_mouse.jsx";
import "./page_emulators.jsx";
import "./page_casestudies.jsx";
import "./page_glossary.jsx";

const SITE_PAGES = [
  { route: "overview", file: "index.html", title: "LainDOS - source, annotated" },
  { route: "boot", file: "boot.html", title: "LainDOS - The Boot Path" },
  { route: "dosapi", file: "dosapi.html", title: "LainDOS - INT 21h" },
  { route: "tests", file: "tests.html", title: "LainDOS - Regression Ladder" },
  { route: "fs", file: "filesystem.html", title: "LainDOS - FAT Filesystem" },
  { route: "mem", file: "memory.html", title: "LainDOS - Memory" },
  { route: "prog", file: "programs.html", title: "LainDOS - Programs" },
  { route: "shell", file: "shell.html", title: "LainDOS - Shell" },
  { route: "mouse", file: "mouse.html", title: "LainDOS - Mouse" },
  { route: "emulators", file: "emulators.html", title: "LainDOS - Emulator Workflows" },
  { route: "cases", file: "casestudies.html", title: "LainDOS - Bug Case Studies" },
  { route: "glossary", file: "glossary.html", title: "LainDOS - Glossary" },
  { route: "run", file: "run.html", title: "LainDOS - Run It" },
];

const PAGE_BY_ROUTE = Object.fromEntries(SITE_PAGES.map(page => [page.route, page]));
const ROUTE_BY_FILE = Object.fromEntries(SITE_PAGES.map(page => [page.file, page.route]));

function normalizeRoute(route) {
  if (!route || route === "index") return "overview";
  if (route === "filesystem") return "fs";
  if (route === "memory") return "mem";
  if (route === "programs") return "prog";
  return route;
}

function hrefFor(target) {
  if (!target) return "index.html";
  const [rawRoute, ...rest] = String(target).split("/");
  const route = normalizeRoute(rawRoute);
  const page = PAGE_BY_ROUTE[route] || PAGE_BY_ROUTE.overview;
  const hash = rest.length ? `#${encodeURIComponent(rest.join("/"))}` : "";
  return `${page.file}${hash}`;
}

function routeFromLocation() {
  if (typeof window === "undefined" || !window.location) return "overview";
  const file = window.location.pathname.split("/").pop() || "index.html";
  return ROUTE_BY_FILE[file] || "overview";
}

function bootStageFromHash() {
  if (typeof window === "undefined" || !window.location || !window.location.hash) return "s0";
  return decodeURIComponent(window.location.hash.slice(1)) || "s0";
}

function App({ initialRoute, initialSub }) {
  const route = normalizeRoute(initialRoute || window.LAIN_PAGE || routeFromLocation());
  const firstSub = initialSub || (route === "boot" ? bootStageFromHash() : "s0");
  const [sub, setSub] = React.useState(firstSub);
  const [scrollReq, setScrollReq] = React.useState(route === "boot" && firstSub !== "s0" ? { id: firstSub, n: 0 } : null);
  const reqN = React.useRef(scrollReq ? 1 : 0);

  const go = (target) => {
    const [rawRoute, ...rest] = String(target).split("/");
    const nextRoute = normalizeRoute(rawRoute);
    const href = hrefFor(target);
    if (nextRoute === route && nextRoute === "boot" && rest.length) {
      const s = rest.join("/");
      if (window.history) window.history.pushState(null, "", href);
      setSub(s);
      reqN.current += 1;
      setScrollReq({ id: s, n: reqN.current });
      return;
    }
    window.location.href = href;
  };

  const navRoute = route === "boot" ? `boot/${sub}` : route;
  let page;
  if (route === "overview") page = <window.OverviewPage go={go} />;
  else if (route === "boot") page = <window.BootPage scrollReq={scrollReq} onActive={setSub} go={go} hrefFor={hrefFor} />;
  else if (route === "dosapi") page = <window.DosApiPage go={go} />;
  else if (route === "tests") page = <window.TestsPage go={go} />;
  else if (route === "fs") page = <window.FilesystemPage go={go} />;
  else if (route === "mem") page = <window.MemoryPage go={go} />;
  else if (route === "prog") page = <window.ProgramsPage go={go} />;
  else if (route === "shell") page = <window.ShellDocsPage go={go} />;
  else if (route === "mouse") page = <window.MouseDocsPage go={go} />;
  else if (route === "emulators") page = <window.EmulatorsPage go={go} />;
  else if (route === "cases") page = <window.CaseStudiesPage go={go} />;
  else if (route === "glossary") page = <window.GlossaryPage go={go} />;
  else if (route === "run") page = <window.RunPage go={go} />;
  else {
    const item = window.NAV.find(n => n.id === route);
    page = <window.StubPage item={item} go={go} />;
  }

  return (
    <div style={{ minHeight: "100vh", background: "#f7f1e6" }}>
      <window.Sidebar route={navRoute} go={go} hrefFor={hrefFor} />
      <main className="site-main" style={{ marginLeft: 282, minWidth: 0 }}>{page}</main>
    </div>
  );
}

function mount() {
  const root = document.getElementById("root");
  if (!root) return;
  ReactDOM.createRoot(root).render(<App />);
}

Object.assign(window, { SiteApp: App, SITE_PAGES, hrefFor });

if (typeof document !== "undefined") {
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount);
  else mount();
}

export { App, SITE_PAGES, hrefFor };
