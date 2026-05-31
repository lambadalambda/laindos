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

const GLOSSARY_TERMS = [
  { term: "86Box", category: "Emulators", aliases: ["86Box"], definition: "A PC emulator used here as a period-hardware comparison target when QEMU behavior looks suspicious." },
  { term: "BIOS", category: "Boot", aliases: ["BIOS"], definition: "Firmware services available before DOS exists; it loads the boot sector and provides interrupts such as INT 13h disk I/O." },
  { term: "Bochs", category: "Emulators", aliases: ["Bochs"], definition: "A debugger-friendly x86 emulator useful as a third opinion when QEMU and 86Box disagree." },
  { term: "BPB", category: "Filesystem", aliases: ["BPB", "BIOS Parameter Block"], definition: "The FAT boot-sector table that describes sector size, FAT location, root directory size, and cluster layout." },
  { term: "CHS", category: "Disk", aliases: ["CHS"], definition: "Cylinder/head/sector disk addressing used by old BIOS INT 13h calls; it has stricter size limits than LBA." },
  { term: "COM1", category: "Debugging", aliases: ["COM1"], definition: "The first PC serial port. LainDOS uses it as the primary machine-readable debug log." },
  { term: "DOS/4GW", category: "Programs", aliases: ["DOS/4GW"], definition: "A DOS extender that switches games into protected mode while still using DOS for startup and file services." },
  { term: "DOS API", category: "DOS API", aliases: ["DOS API"], definition: "The program-facing DOS service contract, mostly reached through INT 21h in LainDOS." },
  { term: "DPMI", category: "Programs", aliases: ["DPMI"], definition: "DOS Protected Mode Interface, the service layer many protected-mode DOS programs expect from an extender or host." },
  { term: "DTA", category: "DOS API", aliases: ["DTA", "Disk Transfer Area"], definition: "The DOS buffer where FindFirst/FindNext and some FCB calls return directory search results." },
  { term: "EMS", category: "Memory", aliases: ["EMS", "Expanded Memory"], definition: "Expanded Memory Specification: bank-switched memory exposed through an EMS page frame." },
  { term: "FAT12", category: "Filesystem", aliases: ["FAT12", "FAT12/16"], definition: "The 12-bit FAT format used by 1.44 MB floppy images and the early LainDOS boot path." },
  { term: "FAT16", category: "Filesystem", aliases: ["FAT16"], definition: "The 16-bit FAT format LainDOS uses for larger hard-disk style images." },
  { term: "framebuffer", category: "Video", aliases: ["framebuffer"], definition: "The raw pixels currently shown by VGA; smoke tests hash or inspect it when serial output cannot prove gameplay." },
  { term: "INT 13h", category: "BIOS", aliases: ["INT 13h"], definition: "The BIOS disk interrupt used by boot code before the DOS filesystem is available." },
  { term: "INT 21h", category: "DOS API", aliases: ["INT 21h"], definition: "The main DOS API interrupt. Programs select services such as open, read, EXEC, and exit with AH." },
  { term: "INT 33h", category: "Mouse", aliases: ["INT 33h"], definition: "The conventional DOS mouse-driver interrupt implemented by LainDOS for game input." },
  { term: "IVT", category: "Boot", aliases: ["IVT", "Interrupt Vector Table"], definition: "The table at physical address zero containing 256 far pointers for CPU, BIOS, and DOS interrupts." },
  { term: "MCB", category: "Memory", aliases: ["MCB", "Memory Control Block"], definition: "A 16-byte DOS memory header that describes the allocated or free block immediately after it." },
  { term: "monitor socket", category: "Debugging", aliases: ["monitor socket", "monitor sockets"], definition: "A QEMU control channel used to send keys, capture screenshots, inspect registers, or quit scripted runs." },
  { term: "MZ", category: "Programs", aliases: ["MZ"], definition: "The DOS EXE header signature. LainDOS uses it to distinguish EXE files from flat COM programs." },
  { term: "NASM", category: "Source", aliases: ["NASM"], definition: "Netwide Assembler, the assembler used for LainDOS boot, kernel, shell, and focused test programs." },
  { term: "PIC", category: "Hardware", aliases: ["PIC"], definition: "The Programmable Interrupt Controller that masks and dispatches hardware IRQs such as keyboard IRQ1." },
  { term: "PIT", category: "Hardware", aliases: ["PIT"], definition: "The Programmable Interval Timer that drives the classic PC timer tick and many game timing loops." },
  { term: "PSP", category: "Programs", aliases: ["PSP", "Program Segment Prefix"], definition: "The DOS data block placed before each program, holding terminate vectors, the job file table, command tail, and environment pointer." },
  { term: "QEMU", category: "Emulators", aliases: ["QEMU"], definition: "The default fast emulator for automated LainDOS builds, tests, monitor probes, and game smoke runs." },
  { term: "QEMU FAT export", category: "Disk", aliases: ["QEMU FAT export"], definition: "QEMU's file=fat:rw drive mode, which exposes a host directory as a DOS FAT drive for quick real-DOS comparisons." },
  { term: "real DOS", category: "Emulators", aliases: ["real DOS"], definition: "A comparison run using MS-DOS, PC DOS, or FreeDOS instead of LainDOS to separate guest bugs from emulator bugs." },
  { term: "real mode", category: "CPU", aliases: ["real mode", "x86 real mode"], definition: "The original 8086-compatible CPU mode where addresses are segment:offset and there is no memory protection." },
  { term: "retrace", category: "Video", aliases: ["retrace", "VGA retrace"], definition: "The VGA vertical-blank signal that many games poll through port 0x3DA for timing." },
  { term: "SAHF", category: "CPU", aliases: ["SAHF"], definition: "An x86 instruction that loads status flags from AH; Ascendancy exposed a QEMU TCG parity-flag bug here." },
  { term: "SB16", category: "Sound", aliases: ["SB16", "Sound Blaster 16"], definition: "Sound Blaster 16 audio hardware. QEMU can emulate it with -device sb16 for game setup tools." },
  { term: "serial log", category: "Debugging", aliases: ["serial log", "serial logging"], definition: "Captured COM1 text output, used by tests to detect PASS, FAIL, exceptions, and unhandled DOS calls." },
  { term: "smoke test", category: "Testing", aliases: ["smoke test", "smoke tests", "game smoke", "game smokes"], definition: "A coarse end-to-end run that proves a game or workflow reaches a visible expected state without fatal markers." },
  { term: "TCG", category: "CPU", aliases: ["TCG"], definition: "QEMU's Tiny Code Generator CPU backend, used when running guests without hardware virtualization." },
  { term: "v86", category: "Emulators", aliases: ["v86"], definition: "A browser-hosted x86 emulator used by the site to boot the small LainDOS demo image." },
  { term: "VGA", category: "Video", aliases: ["VGA"], definition: "The PC video standard LainDOS and the demos use for text and graphics output." },
  { term: "VNC", category: "Emulators", aliases: ["VNC"], definition: "A remote framebuffer protocol QEMU can expose so tests and humans can inspect graphical output headlessly." },
  { term: "XMS", category: "Memory", aliases: ["XMS", "Extended Memory"], definition: "Extended Memory Specification services for memory above 1 MiB, used by many later DOS games and extenders." },
  { term: "x87", category: "CPU", aliases: ["x87"], definition: "The x86 floating-point instruction set. DOS extenders and games may exercise it heavily after startup." },
];

function glossaryAliases() {
  if (window.__GLOSSARY_ALIASES) return window.__GLOSSARY_ALIASES;
  window.__GLOSSARY_ALIASES = GLOSSARY_TERMS.flatMap(entry => entry.aliases.map(alias => ({ alias, entry })))
    .sort((a, b) => b.alias.length - a.alias.length || a.alias.localeCompare(b.alias));
  return window.__GLOSSARY_ALIASES;
}

function GlossaryTerm({ text, entry }) {
  return (
    <span className="glossary-term" tabIndex={0} title={`${entry.term}: ${entry.definition}`}>
      {text}
      <span className="glossary-popover" role="tooltip">
        <span className="glossary-popover-title">{entry.term}</span>
        {entry.definition}
      </span>
    </span>
  );
}

function isBoundary(text, pos) {
  if (pos < 0 || pos >= text.length) return true;
  return !/[A-Za-z0-9]/.test(text[pos]);
}

function glossaryTextParts(text, nextKey) {
  const parts = [];
  let plain = "";
  let pos = 0;
  const aliases = glossaryAliases();
  while (pos < text.length) {
    const match = aliases.find(({ alias }) =>
      text.slice(pos, pos + alias.length).toLowerCase() === alias.toLowerCase()
      && isBoundary(text, pos - 1)
      && isBoundary(text, pos + alias.length));
    if (!match) {
      plain += text[pos++];
      continue;
    }
    if (plain) {
      parts.push(plain);
      plain = "";
    }
    const shown = text.slice(pos, pos + match.alias.length);
    parts.push(<GlossaryTerm key={nextKey()} text={shown} entry={match.entry} />);
    pos += match.alias.length;
  }
  if (plain) parts.push(plain);
  return parts;
}

function InlineText({ text }) {
  if (typeof text !== "string") return text;
  const parts = [];
  let pos = 0;
  let key = 0;
  const nextKey = () => `g${key++}`;
  while (pos < text.length) {
    const start = text.indexOf("`", pos);
    if (start < 0) {
      parts.push(...glossaryTextParts(text.slice(pos), nextKey));
      break;
    }
    const end = text.indexOf("`", start + 1);
    if (end < 0) {
      parts.push(...glossaryTextParts(text.slice(pos), nextKey));
      break;
    }
    if (start > pos) parts.push(...glossaryTextParts(text.slice(pos, start), nextKey));
    parts.push(<code key={nextKey()} style={inlineCodeStyle()}>{text.slice(start + 1, end)}</code>);
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

Object.assign(window, { AsmLine, InlineText, GlossaryTerm, GLOSSARY_TERMS });
