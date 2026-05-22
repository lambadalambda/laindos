# Debug Log

Running notes for non-trivial investigations. Keep this updated with symptoms, confirmed facts, failed hypotheses, commands, and next probes.

## 2026-05-22 Monkey Island Black Screen

### Symptom

- Monkey Island demo loads and switches to graphics mode, but the display remains black.
- Last visible LainDOS file trace reaches `READ H=0005 REQ=03F5 POS=00001B18 BUF=62BC:000E -> 03F5` from `disk01.lec`; after that no further DOS calls are observed in LainDOS during the sampled window.
- DOSBox-X reference continues after that read: closes `disk01.lec`, opens `902.lfl`, opens `904.lfl`, and keeps loading resources.

### Confirmed Facts

- QEMU reports conventional memory as `639 KB`.
- Lowering the MCB arena from `0x3000` to `0x2200` increases Monkey's largest observed allocation from about `0x45DB` to `0x53DB` paragraphs, but does not fix the black screen.
- Monkey installs custom `INT 09h` and `INT 08h` handlers.
- `AH=35h` returned old vectors `INT 09h = F000:E987` and `INT 08h = F000:FEA5`.
- `SETVEC` trace shows Monkey installs `INT 08h = 31F9:0BD5` and `INT 09h = 31F9:558A`.
- After `SETVEC 08`, QEMU monitor showed IF set and BIOS tick dword at physical `0x46C` advancing from `404337` to `404363` over roughly 1.2 seconds.
- Rechecked with current build: IVT bytes at `0x20` are `d5 0b f9 31`, and BIOS tick advanced from `441124` to `441150` over roughly 1.2 seconds.
- Monkey's `INT 08h` handler at physical `0x32B65` increments private state and chains to the BIOS timer vector only every 13 ticks; on other ticks it sends PIC EOI and `iret`s.
- The handler executes direct PIT/speaker I/O through ports `0x42` and `0x61`, so sound/timer interaction exists in the IRQ path.
- Handler private state at `3893:0000` changed across a 1.2 second sample, including countdown `000A -> 0001`, so the game timer IRQ path is executing.
- The `ES:2842` counter touched by the handler sampled as zero before and after a 1.2 second run, likely because the main loop consumes or resets it; it is not by itself proof that IRQ0 is broken.
- Corrected `INT 10h` trace shows Monkey calls `INT 10h AH=1Ah AX=1A00` and then `INT 10h AH=00 AX=000D`, so it selects EGA/VGA graphics mode `0Dh`.
- Sampled execution points are in Monkey's planar VGA copy/retrace code, including direct accesses to ports `0x3CE`, `0x3CF`, and `0x3DA`.
- VGA memory dump at physical `0xA0000` was all zeros after the observed black screen.
- Sending keys after the black screen did not advance file I/O.

### Fixes Made During Investigation

- Added missing symbols for temporary vector tracing: `msg_trace_setvec`, `msg_trace_getvec`, and `vec_num`.
- Made `AH=25h` vector writes disable interrupts while updating the IVT.
- Moved `SEC_BUF` to `0x21C0`, `ENV_SEG` to `0x21E0`, and `MCB_START` to `0x2200` to increase available conventional heap.
- Fixed `AH=3Eh` close so closing an already-closed non-stdio handle returns CF set with `AX=0006` instead of silently succeeding.
- Added `src/closetest.asm` to verify double-close behavior; temporary image output included `PASS: CLOSE`.
- Added `src/regtest.asm` to verify `AH=3Fh` register preservation; it failed before the fix with `FAIL: REGS CLOBBER` and passed after preserving `DX`.
- Fixed `AH=3Fh` to preserve `DX`; Monkey still stops after the same `disk01.lec` `0x03F5` read and VGA screendump remains all black.
- Extended `src/regtest.asm` to verify `AH=42h` preserves `SI`; it failed before the fix with `FAIL: REGS CLOBBER` after a seek and passed after preserving `SI`.
- Fixed `AH=42h` to preserve `SI`; Monkey now advances beyond the previous stall, closes `disk01.lec`, opens `902.lfl` and `904.lfl`, continues loading resources, and a QEMU screendump showed `236000` nonzero bytes out of `768000`.
- Removed temporary `INT 10h`/`INT 11h` hooks and vector target tracing after confirming the fix; final Monkey check still showed `236000` nonzero screendump bytes and continued resource loading.

### Tests And Probes Run

- Built Monkey image with host tools: `python3 scripts/build_monkey.py`; the script writes `build/monkey.img` with a `BOOT_FILE="MIDEMO  EXE"` kernel.
- Booted Monkey under QEMU with serial and monitor sockets to inspect serial trace, registers, IVT entries, timer ticks, MCBs, and VGA memory.
- Used Bochs with `/var/folders/_k/0yhtrj754g59m75jw73827q80000gn/T/opencode/laindos.bochsrc` for debugger probes.
- Bochs breakpoint at physical `0x3AA75` hit Monkey code at `3AA3:0045`, a mode-0Dh planar copy routine; `CX` was zero in the sampled hit.
- QEMU disassembly at physical `0x32B65` confirmed the `INT 08h` handler saves registers, uses `DS=3893`, loads `ES` from `CS:0B6F` (`3C24`), increments `ES:2842`, updates sound state, and conditionally chains via far pointer `CS:0B6B`.
- DOSBox-X reference command:
  `SDL_VIDEODRIVER=dummy /opt/homebrew/bin/dosbox-x -defaultconf -set "logfile=/tmp/dosboxx-mi-compare.log" -fastlaunch -nogui -time-limit 20 -debug -log-int21 -log-fileio -c "mount c vendor" -c "c:" -c "midemo.exe"`

### Failed Or Weakened Hypotheses

- Not a simple stopped-timer case: BIOS tick advanced, IF was set, and the handler's private countdown changed after Monkey installed its `INT 08h` handler.
- Not just a missing keypress or invisible prompt: QEMU `sendkey` attempts did not produce later file activity.
- Not caused solely by too little largest heap block: increasing the largest observed block to `0x53DB` paragraphs did not change the stopping point.
- Offline `scripts/unlzexe.py` is not a useful current control: it produced a 40-byte output for `vendor/midemo.exe`, so it is not a valid decompression comparison yet.
- Not fixed by preserving `DX` across `AH=3Fh` alone.

### Confirmed Root Cause For First Black-Screen Stall

- `AH=42h` clobbered `SI`, and Monkey depended on `SI` surviving the seek before the bulk `disk01.lec` read.
- Preserving `SI` made the observed file-I/O sequence match the DOSBox-X reference past the old stopping point.

### Follow-Ups

- Add automated runs for `close.exe` and `regtest.exe`; they currently require building a kernel with the selected `BOOT_FILE` value.
- Add a repeatable Monkey smoke test around `build/monkey.img` if a stable serial or screendump marker can be checked.
- Reduce remaining file/allocation serial tracing when it is no longer useful for Monkey bring-up.

## 2026-05-22 Mouse Support Bring-Up

### Confirmed Facts

- Current Monkey Island mouse trace starts with `INT 33h AX=0000`, then repeatedly polls `AX=0005` and `AX=000B`.
- `AX=0005` is button-press data; returning zero counts is sufficient when no button has been pressed.
- `AX=000B` is motion counter data; it must return accumulated motion and reset the counters.
- QEMU HMP reports an active `QEMU PS/2 Mouse` with `info mice`.
- Direct polling after `F6`/`F4` PS/2 mouse enable did not receive HMP-injected `mouse_move` events.
- Enabling IRQ12 delivery after the `F6`/`F4` ACK handshake made HMP-injected `mouse_move 40 0` visible to the guest.
- Reading the i8042 command byte with controller command `0x20` timed out in this environment; the current working path uses `0xA8`, mouse `F6`/`F4`, then writes command byte `0x47` to enable keyboard and aux IRQ delivery.

### Fixes Made During Investigation

- Added `src/mousetest.asm` for the software `INT 33h` API: reset/install, set/get position, range clamping, show/hide, button press query, and motion counters.
- Added a built-in `INT 33h` state machine for `AX=0000`, `0001`, `0002`, `0003`, `0004`, `0005`, `0007`, `0008`, `000B`, and `000C` callback address storage.
- Added PS/2 mouse initialization and packet decoding for standard 3-byte packets.
- Added an IRQ12 handler at `INT 74h` that feeds mouse bytes into the packet decoder and sends EOIs to both PICs.
- Added `src/mousehw.asm`, an optional hardware probe that waits for non-zero motion from `INT 33h AX=000B`.

### Tests And Probes Run

- `make test` passed with the mouse code included in the default disk image.
- `mousetest` image booted with `BOOT_FILE="MOUSE   EXE"` and printed `PASS: MOUSE`.
- `mousehw` image booted with `BOOT_FILE="MOUSEHW EXE"`; a QEMU monitor `mouse_move 40 0` injection produced `PASS: MOUSEHW`.
- Monkey image booted with `PS2 mouse enabled`; serial trace showed `INT 33h AX=0000`, repeated `AX=0005`, and repeated `AX=000B`, with no `File not found` or exception during the sampled window.

### Follow-Ups

- Verify real interactive mouse movement in a graphical QEMU run, not just HMP injection under `-nographic`.
- Decide whether to keep always-on `INT 33h` serial tracing or gate it behind a build flag once Phase 8 stabilizes.
- Revisit i8042 command-byte read/write handling if targeting hardware or emulators stricter than QEMU.
- Implement `INT 33h AX=0006` release data and `AX=000Ch` callback invocation if the game needs edge-triggered release or callback behavior.
