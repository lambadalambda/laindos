// page_casestudies.jsx - bug case studies in the long form: background
// first, so the system is understood before the bug appears; then the
// hunt with its dead ends kept in; then the bug, the fix, and the
// regression test that pins it. The happy path explains what the code
// does; these essays explain why it is shaped the way it is.

const CASES = [
  {
    id: "sharebits",
    title: "The Share-Bits Handle Leak",
    game: "Command & Conquer: Red Alert (1996)",
    kicker: "A packed byte, half-masked",
    background: [
      "When a DOS program opens a file, it calls INT 21h with AH=3Dh and gets back a small integer - a file handle. Behind that integer sit two tables. The kernel keeps a global table of open-file state (position, size, where the file lives on disk); the process keeps a tiny per-process table in its PSP, the Job File Table, which maps the handle numbers a program sees onto the kernel's slots. LainDOS sizes the global table at twenty entries, the first five reserved for stdin, stdout, and friends - so a program can hold about fifteen files open at once. That sounds tight until you remember that era programs open, read, and close in quick succession; fifteen concurrent files was generous in 1996.",
      "The other half of this story is the mode byte the program passes in AL. In DOS 1.x it was simple: 0 for read, 1 for write, 2 for both. Then DOS 3.0 grew networks and SHARE.EXE, and the byte got subdivided: the low three bits kept the access mode, and the middle bits gained a sharing mode - a declaration of how other processes may open the same file concurrently. 'Deny none' (0x20) says: I am reading this, and anyone else may do whatever they like. Compilers' runtime libraries emitted these bits by default for years. A program that opens a file with AX=3D20h is not doing anything exotic; it is being a well-mannered citizen of a world that might contain a network.",
      "One more piece: when a handle is closed, DOS has a chore to do if - and only if - the file was written. A written file's directory entry must be updated with the new size and timestamp. A file that was only read needs nothing; the close just returns the slot to the table.",
    ],
    scene:
      "EA released the Red Alert ISOs as freeware in 2008, which made it an irresistible bring-up target. The C: image built, the disc mounted, the DOS installer launched - and drew nothing. A black screen, with the CD activity light pegged solid, for as long as anyone cared to wait. The same black screen appeared under QEMU and 86Box, which was the first useful fact: whatever this was, it was not an emulator quirk. It was ours.",
    investigation: [
      "The kernel has a tracing mode that logs INT 21h calls over serial, so the next step was to simply watch what the installer did. The trace looked perfectly healthy: open D:\\SETUP\\SETUP.MIX, seek, read a few hundred bytes, close, repeat - a Westwood program pulling UI assets out of its MIX archive, one at a time. Nothing failed. Nothing hung. And yet, reading more carefully, something was off: every open returned a fresh handle. 5, 6, 7, 8 ... 0x13. Closes were issued for every one of them - and the numbers still climbed. After handle 0x13, the last slot in the table, the trace degenerated into a wall of identical opens: forty thousand attempts in ninety seconds, every one failing, the installer patiently retrying its asset loads forever. There was the black screen, and there was the constant CD access.",
      "The natural suspicion was a handle leak in the CD path, so the natural move was a minimal repro: a little program that opens a CD file and closes it, fifty times in a loop, printing the handle each time. It printed 5 5 5 5 5 - perfect reuse. A second repro ran as a shell child, like the installer; a third opened a file in a subdirectory, like the installer. All clean. Three repros, each copying one more circumstance of the real thing, and none of them leaked. A repro that refuses to fail is information: it means the bug lives in a variable you have not copied yet.",
      "Rather than guess at a fourth circumstance, the next instrument went under the calls: a serial mark on every slot allocation (+N), every slot release (-N), and every error exit in the close path. The ledger told a very different story from the call trace: opens allocated, closes returned success to the program - and no release ever ran. Route markers narrowed the disappearance to one branch. The close had decided this file was written and needed its directory entry flushed; the flush failed - the CD is read-only and a CD handle has no directory entry to update, only a placeholder - and the error path bailed out before the line that frees the slot.",
      "Why did the close think a read-only file on read-only media had been written to? Because the installer opened it with AX=3D20h - read access, deny-none sharing - and the close path tested the whole stored mode byte against zero. The share bits made the byte nonzero, and nonzero meant 'writable'. The three repros had all opened with AL=0. The discriminating variable was never what the installer did; it was one bit in how it asked.",
    ],
    instrument:
      "Ledger the resource, not the calls. The call trace swore everything was fine, because at the call level everything was fine. Only pairing allocations with releases exposed that closes consumed slots without returning them.",
    bug:
      "The decision 'does this file need its directory entry flushed on close?' is an access-bits question, but the code asked it of the whole mode byte. The kernel's write path had always masked correctly - writes really did require write access - which is exactly why writing files never misbehaved and the bug could sit in the close path unnoticed until a program with polite sharing habits met read-only media.",
    before: [
      "    ; close_root_handle, before: the whole mode byte decides",
      "    cmp byte [cs:si+handles+H_MODE], 0",
      "    je .mark_free",
      "    call flush_handle_dir_entry      ; share bits land here...",
      "    jc .err                          ; ...the CD flush fails...",
      "                                     ; ...and the slot never frees",
    ],
    fix:
      "Mask the access bits before deciding, the same way the write path always had. With the mask in place a deny-none read closes like any read: no flush, slot freed, and Red Alert's installer paints its red Westwood setup screen where six minutes of black used to be.",
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
    epilogue:
      "When a field packs two concerns into one byte, every consumer needs the same mask - and the day you add the second concern is the day to audit all of them. DOS 3.0 added sharing bits in 1984; this bug was that audit, arriving forty-two years late.",
  },
  {
    id: "signext",
    title: "The Sign-Extended Segment",
    game: "The Settlers II Gold Edition (1996)",
    kicker: "A game bug that real DOS hides",
    background: [
      "Real-mode x86 addresses memory through segment:offset pairs: the linear address is segment times sixteen, plus offset. The segment is just a 16-bit number, and nothing about the architecture says it is signed or unsigned - shifted left four bits it covers the famous one megabyte either way. But the moment a protected-mode program converts a real-mode pointer to a flat 32-bit address in C, the question suddenly matters: shift a *signed* 16-bit segment like 0x9F8B left by four and the compiler sign-extends first, producing 0xFFF9F8B0 instead of 0x0009F8B0. Segments at 0x8000 and above have the sign bit set; segments below do not.",
      "DOS/4GW-era games do this conversion all the time. The game runs in protected mode, but the BIOS and DOS still live in real mode, so the game allocates a small real-mode 'transfer buffer', asks DOS where it landed, and converts that segment to a flat pointer to read the results of real-mode calls - VESA video mode queries, for instance. Where does the buffer land? Wherever DOS's allocator puts it. Real DOS uses first fit: scan the memory arena from the bottom, take the first free block that is big enough. For a freshly started program, that means low addresses - segments like 0x0Bxx - and a sign bit that is never set.",
      "Separately: DOS does not own all 640K. The BIOS keeps an Extended BIOS Data Area at the very top of conventional memory and reports the boundary through INT 12h - typically 639K, not 640. The last kilobyte is where, among other things, the BIOS PS/2 mouse services keep their state. A DOS that hands that kilobyte to programs is lending out the BIOS's desk.",
    ],
    scene:
      "Settlers II Gold installed cleanly from its CD and then died on launch: DOS/4GW reported a divide-by-zero inside what disassembled to a VESA bank-switching routine, before the game drew a single pixel. The same binary ran fine on real MS-DOS 5 - which is the kind of fact that simultaneously clears the game and convicts the host.",
    investigation: [
      "The crash math worked back to a VBE video-mode record that was all zeros - yet the kernel had verifiably filled that record in. The game was reading its mode record from somewhere other than where the kernel wrote it. The kernel wrote it to the transfer buffer at segment 0x9F8B; the game read it from flat address 0xFFF9F8B0. Sign extension. The game's conversion is simply buggy - and has been since 1996.",
      "So why did the same binary work on real DOS? Because on real DOS the buffer never lands that high. LainDOS at the time carried an early allocation heuristic that biased small allocations toward the top of the arena - a leftover from bring-up days that had quietly survived because nothing had ever objected. Real DOS's first fit hands out low segments, where the sign bit cannot be set, and so the game's latent bug never fires. There was nothing to patch in the game; there was a default to make faithful in the host.",
      "Pulling that thread surfaced a second, unambiguous kernel fault: the arena's top end was hardcoded at 640K, but INT 12h on this machine says 639K. The kernel had been handing out the EBDA - and the BIOS mouse services were scribbling on whatever program data landed there. Two fixes, then: size the arena from the BIOS's own answer, and retire the high-bias heuristic in favor of plain DOS first fit. Removing the bias immediately exposed two of our own test programs that had been under-allocating overlay buffers and getting away with it because last-fit placement happened to park them harmlessly - the suite's way of collecting its toll.",
    ],
    instrument:
      "When the same binary works on real DOS and fails here, stop reading game code and start diffing environments. The difference is usually a default: where memory lands, what a field is initialized to, which way a tie breaks.",
    bug:
      "Two faithfulness gaps stacked. The arena top ignored INT 12h and lent out the BIOS's EBDA; the allocator biased small requests high, manufacturing segments with the sign bit set that no real DOS would ever produce for a fresh program - and that one game on one afternoon finally noticed.",
    before: [
      "    ; arena top, before: hardcoded to 640K -- the EBDA included",
      "    mov ax, MEM_TOP - MCB_START - 1",
      "    mov word [es:3], ax",
      "    ; allocation strategy, before: small requests biased high",
      "    cmp word [cs:am_req], SMALL_ALLOC_HIGH_MAX",
      "    jbe .am_strat_high               ; buffers land at 0x9F8B...",
    ],
    fix:
      "The arena now ends where INT 12h says conventional memory ends, and allocation is plain first fit. The Settlers II buffer lands low, its sign bit stays clear, and the game runs to its menu - its own bug intact, exactly as on the machines it shipped for.",
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
    pin: "test_memtop: the arena top must respect the INT 12h line and stay out of the EBDA; the MI2 and Settlers II smokes pin first-fit placement downstream.",
    epilogue:
      "Era programs encode their authors' machines. A compatibility DOS does not get to choose clever defaults, because every divergence from the boring ones is a latent bug in somebody's 1996 release waiting for permission to fire. Faithfulness is not pedantry; it is the contract.",
  },
  {
    id: "mediacheck",
    title: "The Disk Swap Nobody Saw",
    game: "Wing Commander (1990)",
    kicker: "Caches versus physical reality",
    background: [
      "Floppy drives are slow, so every DOS that ever mattered cached aggressively: the FAT and the root directory live in RAM after the first read, and most file lookups never touch the hardware again. For a fixed disk this is free performance. For a floppy it is a standing bet that the disk in the drive is still the disk you read - and the user can lose that bet for you at any moment, with one hand, mid-installer.",
      "The hardware offers a partial answer: drives assert a change line, a signal that trips when the door opens, and INT 13h AH=16h reads it back. But the change line only helps if somebody asks, and a kernel serving everything from cache has no reason to ask. Real DOS therefore wraps it in a protocol called the media check, run before trusting cached volume data on a removable drive - softened by a famous heuristic, the 2-second rule: if the disk was verified within the last two seconds (36 timer ticks), assume it has not changed, because no human swaps floppies that fast. Every era DOS programmer eventually meets this rule; it is why rapid-fire file operations on a floppy do not spend half their time interrogating the drive.",
    ],
    scene:
      "Wing Commander's installer copies disk 1, prompts for disk 2, and waits. The disk was swapped - via the emulator's media-change command, the equivalent of an instant hand - and the installer kept reading disk 1's directory forever. A minimal repro needed no game at all: switch to A:, swap the disk, TYPE a file from the new disk. File not found. DIR listed the old disk, indefinitely.",
    investigation: [
      "The previous floppy work had handled the case where a physical read hits the change line: the read fails with error 06h, the kernel remounts the volume and retries. The trap in the installer scenario is that there is no physical read. The prompt-and-swap happens while A: is the current drive, every lookup after the swap is answered from the cached FAT and root directory, and the change-line error has no read to surface through. The cache was not wrong about anything it had been told; it had simply stopped being told things.",
      "The fix is real DOS's own move: a media check on the trust-the-cache path. Before serving cached volume state for a removable drive, check the tick count against the 2-second rule, and past it, ask AH=16h whether the disk changed. Straightforward - until QEMU added its twist. QEMU's change line latches: once it has tripped, AH=16h answers 'changed' forever, even immediately after successful reads. Trusting that answer naively meant remounting the volume on every file operation, which discarded pending FAT state - and five write tests promptly failed. The suite was making a point: the fix had a bug.",
      "The resolution is to treat 'changed' as a claim to verify rather than a fact: re-read the first root directory sector and compare it against the cached copy. A mismatch is a different disk - remount. A match is the same disk - or, to be honest, an identical disk, which real DOS cannot distinguish either; the WC install disks are byte-identical DOS 3.x formats with no serial number, so the root sector is the only fingerprint there is.",
    ],
    instrument:
      "Reduce the game-shaped failure to a shell one-liner before debugging anything. And when your fix breaks five unrelated tests, be grateful: the ladder caught the fix's own bug in minutes instead of letting it ship as a slow corruption.",
    bug:
      "Cached volume data was trusted unconditionally whenever the drive had not changed letters - correct for fixed disks, and an open-ended bet for removable ones. With no physical read in the window, the swap was invisible by construction.",
    before: [
      "    ; activate_drive, before: same drive means trust every cached byte",
      "    cmp al, [cs:active_drive_num]",
      "    je .ok                           ; no physical read, no check --",
      "                                     ; a swapped disk stays invisible",
    ],
    fix:
      "The same-drive path now runs the media check: 2-second rule first, then the BIOS change line, then - because the emulator's change line cannot be trusted to clear - a root-sector content compare before any cached state is discarded. Swaps are seen; clean change lines stay fast; pending writes survive.",
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
    pin: "test_hdfloppy: the stay-on-A: swap scenario - stale data must be rejected and the new volume mounted, while the write suite proves clean change lines are still trusted.",
    epilogue:
      "A cache is a claim that the world will hold still. Removable media exists specifically to break that claim, which is why real DOS carried not just an API for floppies but a small institutionalized paranoia about them. Faithfulness meant copying the paranoia too.",
  },
  {
    id: "busybit",
    title: "The Inverted CD Player",
    game: "The Settlers II Gold Edition - CD audio",
    kicker: "A missing status bit runs a UI backwards",
    background: [
      "CD audio in DOS games does not stream through the program. The drive plays Redbook tracks by itself, analog audio routed straight to the sound card; the program is only a remote control. The remote-control protocol is MSCDEX's device-request interface: INT 2Fh AX=1510h hands the CD driver a request header - a little packet with a command code and a status word - for commands like Play Audio, Stop Audio, and read-the-table-of-contents.",
      "Because playback happens without the program, the program's only window into 'is music playing right now?' is that status word. The spec gives it a busy bit, 0x0200, which the driver must set in completed requests while an audio play operation is in progress. This is load-bearing in a way that is easy to underestimate: a CD player UI fires Play and then polls some request - any request - watching the busy bit to learn whether the track is still going, has finished, or never started. The data path can be perfect; if that one bit is wrong, the UI is flying on a broken instrument.",
    ],
    scene:
      "After CD audio support first landed, the user report read like a riddle: the game lists all eight soundtrack titles - so the TOC plumbing works - but selecting a track plays nothing, while the 'stop playback' button starts the music. Pressing stop again does nothing. Clicking around stops it again.",
    investigation: [
      "The first useful observation came from outside the guest entirely: 86Box's status-bar CD icon flipped to 'playing' the instant a track was selected. The Play command demonstrably reached the drive and the drive demonstrably obeyed - and then the game immediately told it to stop. The UI was not broken; it was acting, correctly and consistently, on wrong information.",
      "That reframing - consistently wrong, not randomly wrong - is the tell for a bad status channel. The game fires Play, polls for the busy bit, sees it clear (because the kernel never set it), and concludes the track has already finished; so it tidies up by stopping the drive. Its internal state now says 'stopped' while reality briefly said 'playing'. Every button press thereafter toggles a state machine that is the mirror image of the hardware: 'stop' from a state that thinks it is stopped means 'start the selected track', which is why the stop button played music.",
      "A second spec subtlety surfaced in the same pass: Stop Audio, command 133, is not a hard stop. The spec gives it pause semantics - keep a resume point so Resume Audio (136) can continue - which maps to ATAPI's PAUSE/RESUME, not its STOP. Both halves answer from the drive's own sub-channel state now, rather than from anything the kernel guesses.",
    ],
    instrument:
      "A UI that misbehaves consistently is faithfully executing on one bad input. Find the instrument it flies by - here, one status bit - before debugging any of its reactions.",
    bug:
      "Every device request returned its status word with the done bit and nothing else. The busy bit the spec promises during audio playback simply did not exist, so every polling CD player concluded that every track ended the moment it began.",
    before: [
      "    ; request status, before: done bit only -- never busy",
      ".ok:",
      "    mov ax, 0x0100",
      ".status:",
      "    mov [es:bx+3], ax                ; the game polls bit 9 in vain",
    ],
    fix:
      "Every completed request now asks the drive, via READ SUB-CHANNEL, whether audio is in progress, and ORs the busy bit into the status word accordingly. Track selection plays, stop stops, and the jukebox in Sam & Max's compilation menu confirmed the same path from a second, unrelated program.",
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
    epilogue:
      "Specs hide load-bearing bits in their status words. You can implement every data path a protocol has and still fail it completely, if the program cannot see what the hardware is doing. The bit cost one OR instruction; its absence cost the whole feature.",
  },
  {
    id: "bootblock",
    title: "The Bug Was in the Test",
    game: "Red Alert bring-up - a 'kernel CD hang' that wasn't",
    kicker: "Every clue real, every clue downstream",
    background: [
      "A .COM file is the simplest executable format ever shipped: no header, no relocations, no metadata - the file is memory, loaded at offset 0x100, run. Crucially, it also has no BSS section, no way to declare 'I need this much scratch space beyond my file'. So DOS supplies a convention instead: a .COM gets the largest free block of memory, usually all of it, with the stack pointer parked at the top of the segment (0xFFFE) and the zero word at [SP]. Era programs lean on this hard - their buffers simply live past the end of the image, in space the format gives them no way to ask for. The flip side of the convention is the shrink: a program that wants to spawn a child must first give memory back with AH=4Ah, which is why every well-written .COM of the era carries a little resize prologue.",
      "LainDOS's boot launcher - the path that starts the test program named at build time - predated all of this nuance. It allocated a block sized to the file plus a few kilobytes of slack, placed at the top of the arena, with SP at the cramped block's top. Every boot-launched test program in the suite had been living a few kilobytes from its own stack without knowing it.",
    ],
    scene:
      "While chasing Red Alert's installer, a new CD stress test - read a 200 KB file in adversarial chunk sizes and verify every byte - hung the machine. Deterministically, and with surgical specificity: a 6144-byte read at offset 12287 hung; a 4096-byte read at the same offset worked; an aligned 6144-byte read worked. The kernel's CD path was the obvious suspect, and the debugger dumps were damning: a corrupted disk-address packet, BIOS work areas full of garbage, and an INT 21h frame that appeared to have been invoked from inside the BIOS itself.",
    investigation: [
      "Hardware watchpoints under QEMU's TCG slow the guest a hundredfold, so the productive instrument turned out to be old-fashioned: serial markers compiled into the kernel at each stage of the read path. They exonerated everything, one stage at a time. The read completed; every byte landed; the stack was balanced to the word; the syscall's exit path was reached; the final IRET executed - and control never arrived back in the program. The return frame the IRET consumed had been overwritten while it waited on the stack.",
      "The 'BIOS context' values in the overwritten frame - a stack segment of 0x9E90, suspiciously like SeaBIOS's work area - sent the hunt through the BIOS, the extended BIOS data area, A20 wrap theories, and interrupt-vector archaeology. All of it was real evidence, and all of it was wreckage rather than cause. The decisive datum cost one instruction: make the test program print its own SS:SP. It really was running with its stack at 0x9E90:12FC - not because anything had corrupted it, but because that is where the boot launcher had legitimately put it: top of the arena, file-sized block, SP at the block top a few KiB past the code.",
      "From there the arithmetic closed the case. The test kept a 30 KB read buffer inside its own image - perfectly legal on real DOS, where a .COM owns its segment. Under the cramped boot block, buffer-plus-image overran the block top where SP lived. Three read iterations stopped just short of the saved INT 21h return frame; the fourth crossed it. The kernel returned, faithfully, into bytes of pattern data. Everything the debugger had shown - the trashed packet, the BIOS garbage, execution wandering through high memory - was the machine's long tumble after that one bad landing.",
    ],
    instrument:
      "When the evidence keeps exonerating suspects, audit the premises instead: print what the program itself sees - its own SS:SP - rather than inferring it. One raw serial write from inside the test settled what hours of kernel forensics could not.",
    bug:
      "Not the CD path at all. The boot launcher violated the .COM memory contract - largest free block, SP at 0xFFFE - and the test program, written to that contract like any era program, overwrote its own stack. A test that breaks an unwritten platform assumption produces evidence indistinguishable from a kernel bug.",
    before: [
      "    ; boot launcher, before: a file-sized block at the arena top",
      ".alloc_com:",
      "    mov bx, [cs:prog_par]            ; image size plus ~4 KiB slack",
      "    call alloc_mem_direct_high       ; parked just under the EBDA,",
      "                                     ; SP at the cramped block top",
    ],
    fix:
      "Make the assumption hold, as the real platform did: both the boot launcher and EXEC now grant a .COM the largest free block, with the DOS-exact entry stack. Twenty-five test programs gained the canonical shrink prologue that real programs always carried - and as a bonus, programs now load above the 64 KiB line, which retired the EXEPACK 'Packed file is corrupt' failure class along with the need for LOADFIX.",
    file: "src/kernel/exec.inc",
    code: [
      [240, ".com_largest:"],
      [245, "    call find_largest_free_block"],
      [246, "    cmp bx, [cs:prog_par]"],
      [248, "    mov [cs:prog_par], bx"],
    ],
    hi: [245, 248],
    pin: "test_boot_mem: a boot-launched COM owns a 64 KiB-plus block with SP at 0xFFFE and the zero word at [SP].",
    epilogue:
      "Tests run inside the same contracts as programs, and a violated contract does not announce itself - it manufactures convincing evidence against innocent code. The humbling part is that the fix was not 'repair the test': it was to make the unwritten assumption true, because on every machine these programs were written for, it always had been.",
  },
];

function BeforeBlock({ lines }) {
  const T = window.T;
  return (
    <div>
      <p style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.6,
        textTransform: "uppercase", color: "#b04a3a", margin: "0 0 6px" }}>Before - the bug</p>
      <pre style={{ background: "#1d1713", color: "#e8d9c5", border: "1px solid #b04a3a",
        borderLeft: "4px solid #b04a3a", borderRadius: 10, padding: "14px 16px", overflowX: "auto",
        fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, lineHeight: 1.65, margin: "0 0 4px" }}>
        {lines.join("\n")}
      </pre>
    </div>
  );
}

function CaseStudyCard({ cs }) {
  const T = window.T;
  const label = { fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.6,
    textTransform: "uppercase", color: T.accent2, margin: "22px 0 8px" };
  const para = { fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 14.5, lineHeight: 1.75,
    color: T.ink, margin: "0 0 12px" };
  return (
    <article id={cs.id} style={{ background: "#fff", border: `1px solid ${T.line}`, borderRadius: 14,
      padding: "30px 34px", marginBottom: 30, boxShadow: "0 1px 0 rgba(0,0,0,0.04)" }}>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11.5, color: T.accent,
        letterSpacing: 1.2, textTransform: "uppercase" }}>{cs.kicker}</div>
      <h2 style={{ fontFamily: "'Newsreader', serif", fontSize: 36, fontWeight: 500, margin: "6px 0 2px", color: T.ink }}>
        {cs.title}
      </h2>
      <div style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.sub, marginBottom: 4 }}>{cs.game}</div>

      <p style={label}>Background</p>
      {cs.background.map((b, i) => <p key={i} style={para}><window.InlineText text={b} /></p>)}

      <p style={label}>What happened</p>
      <p style={para}><window.InlineText text={cs.scene} /></p>

      <p style={label}>The investigation</p>
      {cs.investigation.map((h, i) => <p key={i} style={para}><window.InlineText text={h} /></p>)}

      <div style={{ border: `1px solid ${T.line}`, borderLeft: `4px solid ${T.accent2}`, borderRadius: 8,
        padding: "12px 16px", margin: "4px 0 6px", background: "#fbf7ef" }}>
        <span style={{ fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, letterSpacing: 1.4,
          textTransform: "uppercase", color: T.accent2, marginRight: 8 }}>Field note</span>
        <span style={{ fontFamily: "'Zen Kaku Gothic New', sans-serif", fontSize: 13.5, lineHeight: 1.65, color: T.ink }}>
          <window.InlineText text={cs.instrument} />
        </span>
      </div>

      <p style={label}>The bug</p>
      <p style={para}><window.InlineText text={cs.bug} /></p>
      <BeforeBlock lines={cs.before} />

      <p style={{ ...label, color: "#2f7d4f" }}>The fix - anchored to current source</p>
      <p style={para}><window.InlineText text={cs.fix} /></p>
      <window.CodeBlock file={cs.file} code={cs.code} hi={cs.hi} />

      <p style={label}>Epilogue</p>
      <p style={para}><window.InlineText text={cs.epilogue} /></p>
      <p style={{ ...para, fontFamily: "'IBM Plex Mono', monospace", fontSize: 12.5, color: T.sub, marginBottom: 0 }}>
        <window.InlineText text={`Pinned by ${cs.pin}`} />
      </p>
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
            <window.InlineText text={"The happy path explains what the code does; these essays explain why it is shaped the way it is. Each one starts with the background you need, keeps the wrong turns in - the dead ends carry most of the lesson - and ends at the before/after and the regression test that pins the fix. The raw, unedited journal lives in docs/debug_log.md."} />
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
