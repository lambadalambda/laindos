// page_casestudies.jsx - bug case studies: how things went wrong, how the
// hunts ran, and what each fix pinned down. The happy path explains what
// the code does; these explain why it is shaped the way it is.

const CASES = [
  {
    id: "sharebits",
    title: "The Share-Bits Handle Leak",
    game: "Command & Conquer: Red Alert (1996)",
    kicker: "A packed byte, half-masked",
    symptom:
      "The DOS installer drew nothing: a black screen with the CD light pegged, identical under QEMU and 86Box. The serial log showed no crash, no unhandled call — the machine was busy doing something, forever.",
    hunt: [
      "An INT 21h trace showed a healthy-looking loop: open SETUP.MIX, seek, read, close, repeat — the installer pulling its UI assets out of a Westwood MIX archive. But every cycle consumed a fresh handle number: 5, 6, 7 … 0x13. After fifteen, the handle table was exhausted, and the trace degenerated into 40,000 failed reopens in ninety seconds.",
      "Three minimal repros — a boot program, a shell child, a subdirectory file, each opening and closing in a loop — all reused one handle slot perfectly. The discriminating variable was not what the installer did, but one bit in how it asked.",
      "A slot ledger settled it: a serial mark on every allocation (+N), every release (-N), and every close-path exit. The closes ran, returned, and never printed a release. Route markers narrowed it to one branch: the close decided the file needed its directory entry flushed back, the flush failed on the read-only CD, and the error path skipped the release.",
    ],
    instrument:
      "Ledger the resource, not the calls. The call trace looked perfectly healthy; only marking alloc/release pairs exposed that closes consumed slots without returning them.",
    cause:
      "DOS open modes are a packed byte: the low three bits are access (read/write), the middle bits are sharing. Red Alert opens read-only with deny-none sharing — AX=3D20h, ordinary era behavior. The close path tested the whole stored mode byte against zero to decide whether the file was writable and needed its directory entry flushed; the share bits made a read-only open look writable. The write path had masked the access bits all along — the close path forgot.",
    file: "src/kernel/path_dir.inc",
    code: [
      [326, "close_root_handle:"],
      [328, "    mov ax, [cs:si+handles+H_DIR_LBA]"],
      [330, "    je .mark_free"],
      [334, "    mov al, [cs:si+handles+H_MODE]"],
      [335, "    and al, 7"],
      [336, "    jz .mark_free"],
      [337, "    call flush_handle_dir_entry"],
      [341, ".mark_free:"],
      [343, "    call release_handle_slot"],
    ],
    hi: [334, 335, 336],
    pin: "test_cd_share: thirty deny-none open/close cycles on a CD file must reuse a single handle slot, with every close succeeding.",
    takeaway:
      "Flush-on-close is an access-bits decision. When a field packs two concerns into one byte, every consumer needs the same mask — audit all of them the day you add the second concern.",
  },
  {
    id: "signext",
    title: "The Sign-Extended Segment",
    game: "The Settlers II Gold Edition (1996)",
    kicker: "A game bug that real DOS hides",
    symptom:
      "DOS/4GW died with a divide-by-zero inside a VESA bank-switching routine before the game drew anything. The same binary ran fine on real MS-DOS 5.",
    hunt: [
      "The crash site read zeros out of a VBE mode record that the kernel had verifiably filled in. The transfer buffer the game used for the real-mode VBE call sat at segment 0x9F8B — high in conventional memory, because an early allocation heuristic biased small requests toward the top of the arena.",
      "Settlers II converts real-mode far pointers to flat addresses with a signed segment shift: 0x9F8B << 4 sign-extends to 0xFFF9F8B0. The game read its mode record from a wild address and got zeros. On real DOS the buffer lands low — first fit — where the sign bit never gets touched. The game has the bug; real DOS just never lets it fire.",
      "The same trail flushed out a second, genuine kernel fault: the arena ran to a hardcoded 640K, but INT 12h reports 639K — the last kilobyte is the EBDA, which the BIOS PS/2 services scribble on while DOS runs. Handing it out as program memory corrupted whatever landed there.",
    ],
    instrument:
      "When an emulator-vs-real-DOS comparison says the binary is fine elsewhere, hunt for the environmental difference — here, where allocations land — before reading another line of game code.",
    cause:
      "Two faithfulness gaps stacked: a small-allocation last-fit bias placed buffers at segments with the sign bit set, and the arena top ignored the BIOS's own conventional-memory answer. Restoring plain DOS first fit and sizing the arena from INT 12h made both classes of program assumption hold.",
    file: "src/kernel.asm",
    code: [
      [198, "    ; arena ends at the BIOS conventional-memory line, not at 640K: the"],
      [200, "    mov ax, [mem_kib]"],
      [201, "    mov cl, 6"],
      [202, "    shl ax, cl"],
      [203, "    cmp ax, MEM_TOP"],
      [204, "    jbe .arena_top_ok"],
      [205, "    mov ax, MEM_TOP"],
      [206, ".arena_top_ok:"],
      [207, "    sub ax, MCB_START + 1"],
    ],
    hi: [200, 202, 207],
    pin: "test_memtop: the arena top must respect the INT 12h line and stay out of the EBDA; the MI2 and Settlers II smokes pin the first-fit placement downstream.",
    takeaway:
      "Era programs encode their authors' machines. Faithful defaults (first fit, BIOS-reported limits) are not pedantry — they are the environment those binaries were debugged against.",
  },
  {
    id: "mediacheck",
    title: "The Disk Swap Nobody Saw",
    game: "Wing Commander (1990)",
    kicker: "Caches versus physical reality",
    symptom:
      "The Origin installer prompted for disk 2; the disk was swapped; the installer kept reading disk 1 forever. DIR on the swapped drive listed the old disk's files.",
    hunt: [
      "A minimal shell repro reproduced it without the game: switch to A:, swap the floppy, TYPE a file from the new disk — File not found, stale listing. Every lookup after the prompt was served from the cached FAT and root directory in RAM; no physical read ever happened, so the INT 13h change-line error that the kernel relied on never fired.",
      "Real DOS solves this with the media check: before trusting cached volume data for a removable drive, ask the BIOS whether the disk changed — with a 2-second rule, since a floppy verified within the last 36 ticks is assumed unchanged.",
      "QEMU added a twist: its change line latches. AH=16h answers 'changed' forever, even immediately after successful reads. Trusting it blindly remounted the volume on every file operation and wiped pending FAT state — five write tests failed. The answer is content confirmation: re-read the first root directory sector and compare against the cache before discarding anything.",
    ],
    instrument:
      "Reduce a game-shaped failure to a shell one-liner first. The five failing write tests after the naive fix were the suite earning its keep: the bug's fix had a bug, and the ladder caught it within minutes.",
    cause:
      "The kernel trusted cached volume state on a removable drive with no physical-read traffic to surface the swap. The fix is real DOS's own protocol — 2-second rule, BIOS change-line query, then a root-sector content compare because the emulator's change line cannot be trusted to clear.",
    file: "src/kernel.asm",
    code: [
      [1200, "floppy_media_check:"],
      [1216, "    sub ax, [cs:floppy_check_tick]"],
      [1217, "    cmp ax, 36"],
      [1219, "    mov ah, 0x16"],
      [1221, "    int 0x13"],
      [1222, "    cmp ah, 0x06"],
      [1243, "    repe cmpsw"],
      [1245, "    call floppy_media_remount"],
    ],
    hi: [1217, 1222, 1243],
    pin: "test_hdfloppy: the stay-on-A: swap scenario — stale data must be rejected and the new volume mounted, while the write suite proves clean change lines are still trusted.",
    takeaway:
      "A cache is a claim about the world staying put. Removable media breaks the claim silently; faithfulness here meant copying not just DOS's API but its paranoia.",
  },
  {
    id: "busybit",
    title: "The Inverted CD Player",
    game: "The Settlers II Gold Edition - CD audio",
    kicker: "A missing status bit runs a UI backwards",
    symptom:
      "After CD audio support landed, the game listed all eight Redbook tracks — but selecting a track played nothing, while the 'stop playback' button started the music. Pressing stop again did nothing.",
    hunt: [
      "The emulator's CD icon flipped to 'playing' the moment a track was selected, so the PLAY command demonstrably reached the drive — then the game immediately stopped it. The UI was not broken; it was acting on wrong information.",
      "The CD-ROM device driver spec requires the request status word to carry a busy bit (0x0200) while an audio play operation is in progress. CD player UIs poll exactly that to track state. The kernel never set it, so the instant after PLAY the game saw 'not busy', concluded playback had already finished, and cleaned up. Every button then toggled from a state that was the opposite of reality.",
    ],
    instrument:
      "When a UI behaves consistently wrong rather than randomly wrong, suspect a status channel: the program is faithfully acting on one bad input, and finding that input beats debugging its reactions.",
    cause:
      "Two spec subtleties: the busy bit games poll was missing from every device-request status word, and Stop Audio (command 133) carries pause-with-resume-point semantics, not a hard stop. Both now answered from the drive's own sub-channel state.",
    file: "src/kernel/cdrom.inc",
    code: [
      [1671, "cd_audio_or_busy:"],
      [1674, "    call cd_audio_subchannel"],
      [1676, "    mov cx, CD_BUF"],
      [1678, "    cmp byte [es:1], 0x11"],
      [1680, "    or ax, 0x0200"],
    ],
    hi: [1678, 1680],
    pin: "test_cd_audio pins the request/status contract in the default ladder; actual playback is verified under 86Box, where the mixed-mode cue/bin can mount.",
    takeaway:
      "Specs hide load-bearing bits in their status words. Implement the data path and the protocol still fails if the program cannot see what the hardware is doing.",
  },
  {
    id: "bootblock",
    title: "The Bug Was in the Test",
    game: "Red Alert bring-up - a 'kernel CD hang' that wasn't",
    kicker: "Every clue real, every clue downstream",
    symptom:
      "A new CD stress test hung the machine on a 6144-byte read — but a 4096-byte read at the same offset worked, and an aligned 6144-byte read worked too. Debugger dumps showed a corrupted disk packet, a trashed BIOS work area, and an INT 21h apparently invoked from inside the BIOS.",
    hunt: [
      "Hardware watchpoints made the guest crawl, so the kill came from serial markers compiled into the kernel: the read completed, the stack was balanced, the exit path was reached — and the iret never arrived back in the program. The return frame itself had been overwritten.",
      "The 'BIOS context' values in the parked caller state were the tell: the test program really was running with its stack at segment 0x9E90 — the top of conventional memory. The boot launcher loaded programs into a file-sized block at the top of the arena, and the COM entry convention parked SP at the block top, a few KiB past the code. The test's 30 KiB read buffer ran straight over its own stack. Three read iterations stopped short of it; four reached the saved return frame.",
      "Every dramatic clue — the corrupted disk packet, the BIOS-area garbage, the wandering execution — was wreckage from returning into overwritten memory, not cause. The kernel's CD path was byte-exact all along.",
    ],
    instrument:
      "When evidence keeps exonerating suspects, re-examine the premises: print what the program itself sees (its own SS:SP) instead of inferring it. One raw serial write from the test settled what hours of kernel forensics could not.",
    cause:
      "Real DOS loads a .COM into the largest free block — .COM images carry no BSS, and era programs assume the room past their image is theirs. The file-sized allocation violated that contract for every boot-launched program. Both the boot launcher and EXEC now grant the largest block, with the DOS-exact entry stack.",
    file: "src/kernel/exec.inc",
    code: [
      [240, ".com_largest:"],
      [245, "    call find_largest_free_block"],
      [246, "    cmp bx, [cs:prog_par]"],
      [248, "    mov [cs:prog_par], bx"],
    ],
    hi: [245, 248],
    pin: "test_boot_mem: a boot-launched COM owns a 64 KiB-plus block with SP at 0xFFFE; twenty-five test programs gained the DOS-canonical shrink prologue real programs used before spawning.",
    takeaway:
      "Tests run inside the same contracts as programs. A test that violates an unwritten platform assumption produces evidence indistinguishable from a kernel bug — and the fix may be to make the assumption hold, as the real platform did.",
  },
];

function CaseStudyCard({ cs }) {
  const T = window.T;
  const label = { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.6,
    textTransform: "uppercase", color: T.accent2, margin: "0 0 6px" };
  const para = { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 14.5, lineHeight: 1.7,
    color: T.ink, margin: "0 0 10px" };
  return (
    <article id={cs.id} style={{ background: "#fff", border: `1px solid ${T.line}`, borderRadius: 14,
      padding: "26px 28px", marginBottom: 26, boxShadow: "0 1px 0 rgba(0,0,0,0.04)" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.accent,
        letterSpacing: 1.2, textTransform: "uppercase" }}>{cs.kicker}</div>
      <h2 style={{ fontFamily: "'Newsreader', serif", fontSize: 34, fontWeight: 500, margin: "6px 0 2px", color: T.ink }}>
        {cs.title}
      </h2>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.sub, marginBottom: 16 }}>{cs.game}</div>

      <p style={label}>Symptom</p>
      <p style={para}><window.InlineText text={cs.symptom} /></p>

      <p style={label}>The hunt</p>
      {cs.hunt.map((h, i) => <p key={i} style={para}><window.InlineText text={h} /></p>)}

      <div style={{ border: `1px solid ${T.line}`, borderLeft: `4px solid ${T.accent2}`, borderRadius: 8,
        padding: "12px 16px", margin: "4px 0 16px", background: "#fbf7ef" }}>
        <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.4,
          textTransform: "uppercase", color: T.accent2, marginRight: 8 }}>Instrument</span>
        <span style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, lineHeight: 1.65, color: T.ink }}>
          <window.InlineText text={cs.instrument} />
        </span>
      </div>

      <p style={label}>Root cause &amp; fix</p>
      <p style={para}><window.InlineText text={cs.cause} /></p>
      <window.CodeBlock file={cs.file} code={cs.code} hi={cs.hi} />

      <p style={{ ...label, marginTop: 14 }}>Pinned by</p>
      <p style={para}><window.InlineText text={cs.pin} /></p>

      <p style={label}>Takeaway</p>
      <p style={{ ...para, fontStyle: "italic", marginBottom: 0 }}><window.InlineText text={cs.takeaway} /></p>
    </article>
  );
}

function CaseStudiesPage({ go }) {
  const T = window.T;
  return (
    <div style={{ minHeight: "100vh", background: T.bg }}>
      <header className="hero-bg" style={{ padding: "56px 56px 46px" }}>
        <div style={{ maxWidth: 1120, margin: "0 auto" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontFamily: "'IBM Plex Mono', monospace",
            fontSize: 12, color: "#ffe1c0", letterSpacing: 2, textTransform: "uppercase" }}>
            <span style={{ width: 8, height: 8, borderRadius: "50%", background: "#7ee0d4", flex: "0 0 auto" }} /> Field notes
          </div>
          <h1 style={{ fontFamily: "'Newsreader', serif", fontSize: 76, lineHeight: "76px", fontWeight: 500, margin: "12px 0 16px",
            color: "#fff", textShadow: "2px 2px 0 rgba(0,0,0,0.25)" }}>
            Bug Case Studies
          </h1>
          <p style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", color: "rgba(255,255,255,0.92)", fontSize: 17,
            lineHeight: 1.65, maxWidth: 760, margin: 0 }}>
            <window.InlineText text={"The happy path explains what the code does; these hunts explain why it is shaped the way it is. Each study keeps the wrong turns in - the dead ends carry most of the lesson - and ends at the regression test that pins the fix. The raw, unedited journal lives in docs/debug_log.md."} />
          </p>
        </div>
      </header>

      <div style={{ maxWidth: 880, margin: "0 auto", padding: "34px 56px 60px" }}>
        <nav style={{ marginBottom: 24, fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, lineHeight: 2 }}>
          {CASES.map(cs => (
            <div key={cs.id}>
              <a href={`#${cs.id}`} style={{ color: window.T.accent, textDecoration: "none" }}>{cs.title}</a>
              <span style={{ color: window.T.sub }}> - {cs.game}</span>
            </div>
          ))}
        </nav>
        {CASES.map(cs => <CaseStudyCard key={cs.id} cs={cs} />)}
      </div>
    </div>
  );
}

Object.assign(window, { CaseStudiesPage });
