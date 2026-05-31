// v86machine.jsx — real x86 emulation via v86, booting the LainDOS floppy.
// The image is served same-origin from GitHub Pages so cross-origin reads work.
const LAIN_IMG_URL = window.LAIN_IMG_URL || "shell_monkey.img";
const V86_BASE_URL = "https://cdn.jsdelivr.net/npm/v86@0.5.359%2Bge37189a";
const V86_BIOS_BASE_URL = "https://raw.githubusercontent.com/copy/v86/e37189a/bios";

function fitV86Output(screen) {
  const text = screen.querySelector(":scope > div");
  const canvas = screen.querySelector(":scope > canvas");
  const active = canvas && getComputedStyle(canvas).display !== "none" ? canvas : text;
  if (!active) return;

  active.style.transform = "none";
  const rect = active.getBoundingClientRect();
  const width = active === canvas ? rect.width || canvas.width : active.scrollWidth || rect.width;
  const height = active === canvas ? rect.height || canvas.height : active.scrollHeight || rect.height;
  if (!width || !height || !screen.clientWidth || !screen.clientHeight) return;

  const scale = Math.min(1, screen.clientWidth / width, screen.clientHeight / height);
  active.style.transform = `scale(${scale})`;
}

function V86Machine({ bootKey, onStatus }) {
  const screenRef = React.useRef(null);
  const termRef = React.useRef(null);
  const [view, setView] = React.useState("screen");
  const T = window.T;

  const writeByte = React.useCallback((b) => {
    const el = termRef.current;
    if (!el) return;
    if (b === 8 || b === 127) el.textContent = el.textContent.slice(0, -1);
    else if (b === 13) { /* ignore CR; LF drives newlines */ }
    else el.textContent += String.fromCharCode(b);
    el.scrollTop = el.scrollHeight;
  }, []);

  React.useEffect(() => {
    if (!window.V86) { onStatus("error", "v86 library did not load"); return; }
    const screen = screenRef.current;
    if (!screen) { onStatus("error", "screen container did not mount"); return; }
    screen.replaceChildren(document.createElement("div"), document.createElement("canvas"));
    if (termRef.current) termRef.current.textContent = "";
    setView("screen");
    let started = false, emu;
    try {
      emu = new window.V86({
        wasm_path: `${V86_BASE_URL}/build/v86.wasm`,
        screen_container: screen,
        bios: { url: `${V86_BIOS_BASE_URL}/seabios.bin` },
        vga_bios: { url: `${V86_BIOS_BASE_URL}/bochs-vgabios.bin` },
        fda: { url: LAIN_IMG_URL },
        memory_size: 32 * 1024 * 1024,
        vga_memory_size: 8 * 1024 * 1024,
        autostart: true,
      });
    } catch (e) {
      onStatus("error", String(e && e.message || e));
      return;
    }
    onStatus("booting");
    emu.add_listener("emulator-started", () => { started = true; onStatus("running"); });
    emu.add_listener("serial0-output-byte", writeByte);
    emu.add_listener("download-error", () => onStatus("error", "could not load the floppy image"));
    const t = setTimeout(() => { if (!started) onStatus("stalled"); }, 14000);
    let fitFrame = 0;
    const scheduleFit = () => {
      cancelAnimationFrame(fitFrame);
      fitFrame = requestAnimationFrame(() => fitV86Output(screen));
    };
    const resizeObserver = new ResizeObserver(scheduleFit);
    resizeObserver.observe(screen);
    Array.from(screen.children).forEach(child => resizeObserver.observe(child));
    const mutationObserver = new MutationObserver(scheduleFit);
    mutationObserver.observe(screen, { childList: true, characterData: true, subtree: true });
    window.addEventListener("resize", scheduleFit);
    scheduleFit();
    return () => {
      clearTimeout(t);
      cancelAnimationFrame(fitFrame);
      resizeObserver.disconnect();
      mutationObserver.disconnect();
      window.removeEventListener("resize", scheduleFit);
      try { emu.destroy && emu.destroy(); } catch (e) {}
      screen.replaceChildren();
    };
  }, [bootKey, onStatus, writeByte]);

  const seg = (v, label) => (
    <button key={v} onClick={() => setView(v)} style={{
      fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, padding: "4px 10px", cursor: "pointer",
      border: `1px solid ${view === v ? T.amber : T.line}`, borderRadius: 6,
      background: view === v ? "#1a1a12" : "rgba(0,0,0,0.5)", color: view === v ? T.amber : T.dim }}>{label}</button>
  );

  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div ref={screenRef} className="v86-screen" style={{ display: view === "screen" ? "flex" : "none",
        position: "absolute", inset: 0, alignItems: "center", justifyContent: "center", background: "#000" }} />
      <pre ref={termRef} className="v86-term" style={{ display: view === "serial" ? "block" : "none",
        position: "absolute", inset: 0, margin: 0, overflow: "auto", padding: "12px 14px" }} />
      <div style={{ position: "absolute", top: 8, right: 8, display: "flex", gap: 5, zIndex: 5 }}>
        {seg("screen", "Screen")}
        {seg("serial", "Serial · COM1")}
      </div>
    </div>
  );
}
window.V86Machine = V86Machine;
window.LAIN_IMG_URL = LAIN_IMG_URL;
