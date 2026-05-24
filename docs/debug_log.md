# Debug Log

Running notes for non-trivial investigations. Keep this updated with symptoms, confirmed facts, failed hypotheses, commands, and next probes.

## 2026-05-24 Simon RUNVGA Memory Compatibility

### Symptoms

- After minimal BAT support, `C:\SIMON\SIMON.BAT` could launch `RUNVGA GDEMO /3`, but Simon either returned to the shell or crashed before a stable VGA frame.
- A lower-resident-memory build reached `GDEMO` reads and then hit `EXC 06 at 1607:0FA8`; the bytes at that address were ASCII text from resource data, indicating execution had been redirected into data.
- `RUNVGA.EXE` has `MaxAlloc=FFFF`; LainDOS previously allocated only the computed minimum/image size for EXE loads.

### Confirmed Facts

- DOSBox-X comparison showed `RUNVGA.EXE` resizing its PSP block to `0x416D` paragraphs and then opening/reading `GDEMO`.
- LainDOS now honors EXE MZ `MaxAlloc` for both boot-time EXE loads and `INT 21h AH=4Bh` EXEC. `MaxAlloc=FFFF` uses the largest free MCB; finite values are capped by the largest available block and never below the minimum/file load size.
- Lowering resident buffers made enough conventional memory available for Simon without the unstable partial bootloader low-load experiment. Current layout keeps the kernel loaded at `0x0800`, self-relocates it to `0x0340`, uses boot FAT/root buffers at `0x0060`/`0x0180`, runtime buffers at `0x0840`/`0x0860`, and starts the DOS MCB arena at `0x0900`.
- The partial bootloader low-load experiment was abandoned because it caused BIOS read failure/hang after 8 kernel sectors.
- `GDEMO` data corruption was ruled out: host checksums for the first 12 sectors matched the runtime buffer dump, and Simon's first 512-byte `GDEMO` read matched the host file exactly.
- Root cause of the Simon `EXC 06`: `INT 21h AH=48h` clobbered non-return registers while splitting MCBs, especially `ES`, `DI`, `CX`, and `DX`. Simon depended on those registers surviving allocation calls.
- `AH=48h` now preserves non-return registers on success and failure while still returning `AX` on success and `AX/BX` on failure. `MEMREG.COM` verifies `ES/BX/CX/DX/DI` preservation on success.
- Successful `AH=4Ah` resize of a PSP-owned block now updates `PSP:0002` to the new top-of-memory value. `MEMREG.COM` verifies this.
- Existing EXE tests with `MaxAlloc=FFFF` consumed the whole arena under the corrected loader behavior; their MZ headers were narrowed to finite maxalloc values where the test body still needs later DOS heap allocations.
- Added minimal compatibility stubs for DOS probes seen during Simon bring-up: `AH=0Eh` select disk and `AH=36h` disk free. The IOCTL get-device-info file path returns the current drive in the low bits of `DX`, with bit 7 clear for disk files.

### Tests And Probes Run

- `make test` initially failed after MaxAlloc support because `MEMTEST.EXE` and later `READWRAP.EXE` requested all remaining memory before making explicit `AH=48h` allocations. Updating their MZ maxalloc values fixed those regressions.
- Final `make test` passes, including `PASS: EXEMAX`, `PASS: MEMREG`, and `PASS: READWRAP`.
- `python3 scripts/test_monkey_full.py` passes with framebuffer activity: `111 colors`, `209876 nonblack pixels`.
- `python3 scripts/build_games_hd_all.py` rebuilt `build/games_hd_all.img` with the current kernel.
- Focused QEMU/VNC Simon smoke booted `build/games_hd_all.img`, ran `CD SIMON`, `SIMON`, and captured `build/simon_review.ppm`: PPM `640x400`, `77 colors`, `219128` nonblack pixels, with no `EXC` in serial output.

### Failed Or Weakened Hypotheses

- Not caused by corrupted `GDEMO` FAT reads; checksums and runtime buffer dumps matched host bytes.
- Not fixed by changing DOS version to `AX=0005`.
- Not fixed by read/alloc ZF return experiments.
- INT 21h internal stack switching was not a safe quick fix; the attempted version broke existing COM return flow and was reverted.

### Follow-Ups

- Run a code review before committing the current memory/Simon compatibility changes.
- Preserve `EXEMAX.EXE` and `MEMREG.COM` in the shell regression so EXE MaxAlloc and allocator register preservation do not regress.
- Actual Monkey/MI2/Simon save-load behavior still needs separate interactive verification.

## 2026-05-24 Minimal BAT Support

### Symptoms

- `C:\SIMON\SIMON.BAT` needs to run `RUNVGA GDEMO /3`, but the shell originally treated `.BAT` files as bad commands.
- The first batch implementation repeatedly executed `TESTBAT` instead of the file's `ECHO OFF` and `ARGTEST GDEMO /3` lines.

### Confirmed Facts

- `TYPE TESTBAT.BAT` printed the expected file contents, so the DOS open/read path was not the primary failure.
- Temporary shell tracing showed `run_batch` read `TESTBAT.BAT` correctly, then parsed `line_buf` as the stale top-level `TESTBAT` command.
- Root cause: `batch_read_line` used `stosb` to copy into `line_buf` without setting `ES=DS`; parsed lines were written to whatever segment prior DOS calls left in `ES`.
- Fix: set `ES` from `DS` before `batch_read_line` stores into `line_buf`.
- Added batch coverage for command tails with both COM and EXE children: `ARGTEST.COM` and `ARGEXE.EXE` expect PSP tail ` GDEMO /3`.
- A traced all-games QEMU run now shows `SIMON.BAT` being opened/read and `RUNVGA.EXE` executing DOS memory/vector calls.
- `RUNVGA.EXE` still exits back to `C:\SIMON>` before a traced child `GDEMO` exec appears, so further Simon runtime compatibility remains a separate follow-up.

### Tests And Probes Run

- `python3 scripts/test_shell.py` failed before the fix with repeated stale `TESTBAT` execution and passes after setting `ES=DS` in `batch_read_line`.
- `make test` passes with the batch and command-tail regressions included.
- `python3 scripts/build_games_hd_all.py` rebuilt `build/games_hd_all.img` with `SIMON.BAT` support.
- `python3 scripts/test_monkey_full.py` still passes with framebuffer activity.
- Focused QEMU Simon smoke: boot `build/games_hd_all.img`, `CD SIMON`, `SIMON`; result no shell bad-command error, but prompt returns after `RUNVGA.EXE` exits.
- Temporary trace builds used `-DTRACE_DOS=180` and `-DTRACE_EXEC_STATE=1` to confirm `SIMON.BAT` reads and the `RUNVGA.EXE` child entry state.

### Follow-Ups

- Diagnose why `RUNVGA.EXE` exits before loading or transferring to `GDEMO`.
- Keep the COM/EXE command-tail batch regressions when debugging Simon so tail handling does not regress.

## 2026-05-24 86Box Directory Corruption

### Symptoms

- 86Box could boot the all-games image but directory listings could turn into garbage on higher-LBA subdirectories.
- The same generated `hd20m` images listed directories correctly under QEMU and Bochs.

### Confirmed Facts

- Isolated 86Box VM path: `build/86box-serial-file`.
- COM1 capture works with `[Ports (COM & LPT)] serial1_device = stdio` and `[Virtual Console (COM) #1] mode = 0`.
- COM1 file capture using `serial1_device = file` created the file but captured no bytes in this setup.
- A fresh isolated 86Box VM needed the existing `monkey` VM NVR copied into `build/86box-serial-file/nvr` before it booted unattended.
- Focused temporary `DIRLIST.COM` image enumerated root, `\M1DEMO`, `\MI2`, and `\SIMON` through DOS `FindFirst`/`FindNext`.
- Before the fix, `DIRLIST` passed under QEMU but failed under 86Box at `\MI2` with a bad first DTA name.
- BIOS `INT 13h AH=08` geometry differs by emulator for the same `hd20m` image:
- QEMU reports `CX=263F DX=0F01`, which decodes as 63 sectors/track and 16 heads.
- 86Box reports `CX=123F DX=1F01`, which decodes as 63 sectors/track and 32 heads.
- The `\MI2` directory cluster in the temporary image was at LBA `14639`; BPB geometry maps that to CHS `14/8/24`, while 86Box BIOS translation requires CHS `7/8/24`.
- Root cause: LainDOS used BPB sectors-per-track/head-count for BIOS CHS conversion. That is only safe when BIOS translation matches the BPB.
- Fixed by storing BIOS-reported geometry for hard-disk INT 13h reads/writes, falling back to BPB values if `AH=08` fails or reports invalid SPT.
- Also fixed latent CHS encoding by storing the cylinder as a word and encoding cylinder bits 8-9 into `CL[7:6]` for `INT 13h AH=02h/03h`.

### Tests And Probes Run

- A temporary `build/build_dirlist_image.py` built a direct-boot `DIRLIST.COM` hard-disk image.
- QEMU control: `qemu-system-i386 -drive file=build/dirlist.img,format=raw -boot order=c -serial stdio -monitor none -nographic`.
- 86Box probe: `/Applications/86Box.app/Contents/MacOS/86Box -P /Users/lainsoykaf/repos/laindos/build/86box-serial-file -N`.
- Pre-fix 86Box `DIRLIST` output reached `\MI2` then printed a corrupted name and `FAIL: DIRLIST`.
- Post-fix 86Box `DIRLIST` output lists `\MI2` and `\SIMON` correctly and prints `PASS: DIRLIST`.
- `make test` passes after the fix.
- `python3 scripts/build_games_hd_all.py` rebuilt `build/games_hd_all.img` with the fixed kernel.
- QEMU all-games boot reaches `LainDOS Shell` at `C:\>`.
- `python3 scripts/test_monkey_full.py` passes with framebuffer active (`110 colors`, `209876 nonblack pixels`).
- 86Box all-games boot reaches `LainDOS Shell` at `C:\>` using the isolated VM.

### Failed Or Weakened Hypotheses

- Not a FAT directory mutation bug: the focused image passed QEMU and failed only under 86Box before the geometry fix.
- Not a COM1 logging failure: 86Box `stdio` virtual console captures LainDOS serial output reliably.
- Not fixed by trying `INT 13h AH=42h` from the temporary harness; the robust minimal fix is querying BIOS CHS geometry for the existing AH=02h/03h path.

### Follow-Ups

- Keep using the isolated 86Box VM under `build/86box-serial-file` for future probes instead of mutating user VMs.
- If larger hard-disk images are introduced, revisit the current 16-bit LBA and CHS limits or add a proper EDD path with a CHS fallback.
- Verify actual MI2 save/load behavior from the now-working F5 overlay.

## 2026-05-23 Full MI2 Shell EXEC Follow-Up

### Symptoms

- Full MI2 from the shell now reaches the same purple startup/copy-protection screen as direct boot in a 60-second smoke, but interactive copy-protection/save-load validation remains incomplete.
- Before the latest fixes, shell-root `MONKEY2` could reach copy-protection graphics and then halt with `EXC 06` or exit through `Thanks for using this INC Crack!` depending on tracing/timing.
- QEMU monitor `screendump` can perturb the crack path; runs with repeated screenshots tend to exit sooner than no-screenshot serial runs.

### Confirmed Facts

- MI2's EXE header has `MaxAlloc=FFFF`, `MinAlloc=05D2`, `cparhdr=00E0`, and size 110811 bytes.
- Giving `MaxAlloc=FFFF` EXEs the entire free MCB did not improve the later largest allocation after MI2 shrinks its PSP; shell residency still dominated the final largest block.
- Shrinking the shell MCB is not sufficient by itself. Too little retained stack corrupts `EXEC`; a larger retained stack changed MI2 into a purple-screen stall.
- The original buffer layout left a large unused gap between `FAT_SEG=1000` and `ROOT_SEG=2000`. Moving `ROOT_SEG` to `1200`, `SEC_BUF` to `13C0`, `ENV_SEG` to `13E0`, and `MCB_START` to `1400` raises the shell-run largest MI2 allocation from about `5206` to `6006` paragraphs.
- Lowering `MCB_START` initially overlapped the kernel's saved stack at `0800:FFFE`; moving the kernel stack to `0800:7000` fixed the shell `exit` regression.
- A traced low-arena run reached `EXC 06 at 15A2:FEC2`; bytes at the saved return IP were valid code (`03 E9 CC FE ...`), indicating the vector was reached by a software `INT 06h`, not a CPU invalid-opcode fault.
- Treating software `INT 06h` (`CD 06` at `CS:IP-2`) as an `iret` removes that fatal exception path.
- `INT 21h AH=2Ch` was frozen at 12:00:00. It now derives time from the BIOS tick counter, and `TIMETEST.COM` verifies DOS time changes after a BIOS tick.
- One-shot `TRACE_EXEC_STATE` showed shell MI2 originally differed from direct boot in `PSP:16`, BIOS keyboard buffer head/tail, and child load address/MCB chain.
- `PSP:16` is now set to the previous `cur_psp`; `PSPTEST.COM`/`PSPCHILD.COM` verify nested `EXEC` children see their parent PSP.
- `reset_keyboard_buffer` now rewinds BDA keyboard head/tail to `001E` only when the buffer is already empty; `KEYTEST.COM` verifies DOS/BIOS empty status plus BDA head/tail.
- Direct boot with artificial `MCB_START=1591` reproduced the crack exit (`Thanks for using this INC Crack!`, code `83`), confirming MI2 is sensitive to the child load address/top-of-block state.
- Booting the shell COM high but leaving its MCB visible still made shell MI2 stall in text mode. Hiding the high shell reservation from the DOS MCB chain made shell-launched `C:\MI2\MONKEY2` match direct boot at entry (`PSP=1401`, `TOP=3411`, `ENTRY=23C0:2688`, child MCB followed by a free `Z` block).
- A 60-second VNC/screendump run of shell-launched `C:\MI2\MONKEY2` with the hidden high shell reached the same purple MI2 screen color distribution as direct boot, with no crack exit and no `EXC 06`.
- MI2 reaches the playable bridge scene after copy-protection: `Enter`, `1234`, click the top `all the puzzles` choice, then repeated `Esc` through the intro.
- Gameplay keyboard input is alive for letter shortcuts. At the bridge, `p`, `l`, and `u` visibly select `Pick up`, `Look at`, and `Use`.
- Before the extended-key fix, F5 did not open save/load at the bridge via HMP `sendkey f5`, repeated HMP `sendkey f5` commands, HMP `sendkey f5 1000`, or QMP `input-send-event` with F5 held across frames.
- QEMU IRQ counters prove F5 generates IRQ1 make/break at the bridge (`IRQ1 64 -> 66` for one HMP F5; QMP held F5 increments once on down and once on up).
- QEMU PS/2 trace with `-trace enable=ps2_*` shows `p` as set-2 keycode `4D` and F5 as set-2 keycode `03` with translation enabled; the i8042 set-2 to set-1 table maps these to guest set-1 `19` (`p`) and `3F` (F5), but the actual byte MI2 reads from port `60h` is not yet confirmed.
- QEMU `pckbd_kbd_read_data` trace at the MI2 bridge confirms the guest reads set-1 `19/99` for `p` and `3F/BF` for F5 from port `60h`; the F5 failure is therefore downstream of i8042 translation and IRQ delivery.
- `TRACE_DOS` confirmed full MI2 installs a custom keyboard handler with `GETVEC 09 -> F000:E987` followed by `SETVEC 09 = 23C0:189A`.
- Disassembling the handler showed it consumes arrows/keypad and selected Ctrl combinations itself, but F5 (`3Fh`) falls through to the previous BIOS `INT 09h` handler.
- QEMU BDA dumps after bridge F5 showed the BIOS keyboard buffer receiving `3F00` and head/tail advancing, so MI2 consumed the F5 keystroke from the DOS/BIOS path.
- Root cause for inactive F5: LainDOS `INT 21h AH=07h/08h` returned the first extended-key byte (`AL=00`) but discarded the scan code in BIOS `AH`; DOS callers expect a pending second byte (`AL=3Fh` for F5) on the next character read, and `AH=0Bh` should report that pending byte as available.
- After adding an extended-key pending byte for DOS console input, F5 opens the full MI2 bridge save/load overlay with `Save`, `Load`, `Play`, and `Quit` buttons.

### Tests And Probes Run

- `python3 scripts/test_shell.py` passes after the low-arena move, kernel stack move, software `INT 06h` handling, and DOS time regression.
- Low-arena trace build command used: `nasm -DTRACE_DOS=900 -DBOOT_FILE='"SHELL   COM"' -f bin src/kernel.asm -o build/mi2root_int06_trace_kernel.bin`.
- Low-arena traced MI2 now opens `MONKEY2.001`, performs the large `READ H=0005 REQ=9756 POS=00868A49 ... -> 9756`, polls stdin as empty, and then in traced runs may print `Thanks for using this INC Crack!` and return to the shell.
- Low-arena no-screenshot MI2 serial runs can stay running for 60 seconds with no `EXC`, no `Thanks`, and no shell prompt, but the one late framebuffer capture was still all black.
- `python3 scripts/test_shell.py` failed before the PSP parent fix with `FAIL: PSP`, then passed after `build_psp` wrote `PSP:16`.
- `python3 scripts/test_shell.py` failed before the keyboard reset with `FAIL: BIOS KEY BDA`, then passed after empty-buffer pointer reset before child transfer.
- `python3 scripts/test_shell.py` passes after moving boot COM programs to a hidden high reservation.
- MI2 probe commands used current generated images such as `build/trace_mi2_shell.img`, `build/mi2_hidden_shell.img`, and one late screenshot per run. `build/mi2_hidden_shell_60.ppm` matched direct boot's purple-screen color distribution.
- Final verification after review follow-ups: `make test`, `python3 scripts/test_monkey_full.py`, `git diff --check`, and `python3 scripts/build_games_hd_all.py` plus a 60-second `C:\MI2\MONKEY2` VNC smoke all passed. The MI2 smoke reported `HAS_THANKS False`, `HAS_EXC False`, and a 42-color purple-screen capture.
- F5 investigation screenshots include `build/mi2_keys_02_p.jpg`, `build/mi2_keys_03_l.jpg`, `build/mi2_keys_04_u.jpg`, and `build/mi2_qmp_f5_after.jpg`. QEMU PS/2 trace output is in `build/qemu_ps2_f5_trace.log`.
- `python3 scripts/test_shell.py` reproduced the DOS extended-key bug with the new `EXTKEY.COM` regression before the fix (`FAIL: EXTKEY PENDING`) and passes after the fix (`PASS: EXTKEY`).
- `python3 scripts/build_games_hd_all.py` rebuilt `build/games_hd_all.img`; a bridge run captured `build/mi2_f5_fixed_after.jpg`, showing the F5 save/load overlay open.
- After review follow-ups, pending extended-key state is cleared on process termination and before buffered line input; `test_shell.py` now waits for `READY: EXTKEY` before sending F5. Final checks passed: `make test`, `python3 scripts/test_monkey_full.py`, `git diff --check`, and a final all-games MI2 bridge F5 capture at `build/mi2_f5_final_after.jpg`.

### Failed Or Weakened Hypotheses

- The `EXC 06` path was not necessarily bad decoded code; at least one captured case was a deliberate software `INT 06h`.
- Honoring `MaxAlloc=FFFF` alone did not solve the shell runtime behavior.
- More conventional DOS time did not by itself make MI2 reach copy-protection graphics.
- More free memory removes one constraint but does not by itself fix black-screen/exit behavior.
- Setting only `PSP:16` fixed a real DOS compatibility bug but did not remove the MI2 crack exit.
- Resetting the empty BIOS keyboard buffer removed the immediate crack exit, but low-resident shell still later reached purple plus `EXC 06` in long runs.
- Moving the shell high without hiding its MCB did not work; MI2 still saw a non-direct MCB chain and stalled before graphics.
- F5 failure is not a general gameplay keyboard failure; letter shortcuts work and F5 generates IRQ1.
- F5 failure is not just HMP key timing; QMP held F5 also has no visible effect.
- F5 failure is not caused by the INC crack disabling the menu in this build; once DOS extended-key two-byte reads are implemented, the menu opens.

### Next Probes

- Preserve the hidden-high-shell behavior while continuing from the purple MI2 screen.
- Keep using no-screenshot serial runs for runtime stability checks; take at most one late screenshot because HMP screendumps perturb the crack.
- Continue from the purple MI2 screen with careful single-input probes only after preserving the current stable shell-entry behavior.
- For save/load, next useful probes are testing actual MI2 save and load operations from the now-opening F5 overlay, including resulting `SAVEGAME.xxx` file mutation and reload behavior.

### Advisor Follow-Up Ideas

- First probe should be a low-perturbation child-entry state diff between direct boot and shell `EXEC`, emitted once before transferring to MI2.
- Log child `PSP`, `PSP:02`, `PSP:16`, `PSP:2C`, `PSP:80`, entry `CS:IP`, intended `SS:SP`, `DS`, `ES`, and current DTA.
- Log the first few MCBs from `MCB_START`, plus `ENV_SEG-1` signature/owner/size and first environment bytes, because LainDOS currently points `PSP:2C` outside the MCB arena.
- Log BDA hardware/timing state: equipment word `40:10`, video mode `40:49`, keyboard flags/head/tail, and tick dword `40:6C`.
- Log IVT entries for `06`, `08`, `09`, `10`, `16`, `1A`, `1C`, `22`, `23`, and `24`, plus PIC masks `21h` and `A1h`.
- If the state diff points at `PSP:16`, try setting the child parent PSP to the shell PSP for shell-launched programs.
- If the state diff points at environment semantics, allocate/copy a real child environment block with an MCB instead of using fixed `ENV_SEG` directly.
- If the state diff is not enough, add a RAM ring-buffer flight recorder dumped only on `AH=4Ch`: recent `INT 21h` entry/exit registers, memory calls, overlay calls, `MONKEY2.001` read checksums, software `INT 06h` call sites, and `INT 10h` mode calls.
- Verify whether shell MI2 reaches any `INT 10h AH=00h/1Ah`; if no, keep debugging pre-graphics crack/process state rather than VGA rendering.
- Compare high-offset `MONKEY2.001` read checksums against host bytes if execution diverges after the large `REQ=9756` read.

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

## 2026-05-22 Monkey Island 2 Demo Bring-Up

### Symptoms

- `vendor/mi2demo.zip` contents exceed a 1.44 MB floppy, so the initial image build failed with a full disk.
- After 2.88 MB FAT12 support and environment path setup, MI2 opened `MI2DEMO.000` but failed with `run-time error R6000 - stack overflow` and `R6001 - null pointer assignment`.
- After fixing relocation handling, MI2 reached its startup/input path and exposed missing `INT 21h AH=0Bh` and `AH=08h` keyboard services.
- With keyboard services implemented, MI2 reached `Error 1 loading sound overlay`; DOSBox starts directly into graphics, so this was confirmed as a LainDOS compatibility failure rather than an expected prompt.
- After adding `INT 21h AH=4Bh AL=03h` overlay loading, MI2 started directly into graphics and rendered the playable scene.

### Confirmed Facts

- MI2 MZ header has 1296 relocation entries, far beyond the old fixed `reloc_buf` capacity of 512 bytes.
- The old `setup_exe_dyn` wrote all relocation entries into `reloc_buf`, overflowing into kernel state including handles and `trace_left`; this explained both corrupted trace output and the stack/runtime failure.
- Processing relocations in-place on the source image before copying the image down avoids needing a relocation buffer and preserves MZ relocation semantics.
- `src/bigreloc.asm` reproduced the relocation-buffer overflow before the fix: it emitted an unexpected `OPEN TESTFILE.DAT` trace and failed to open the file because the handle table was corrupted.
- MI2 does not call `INT 21h AH=58h` allocation strategy before its sound overlay allocation. It shrinks its PSP, allocates a tiny `0x001A` paragraph block, then tries to grow the PSP again. Placing tiny allocations high preserves enough low free space for this pattern.
- The sound overlay file lookup succeeds: trace showed `OPEN A:\null.ims -> H=0005 SIZE=00000380`.
- `NULL.IMS` is an MZ-format overlay. The exact `Error 1 loading sound overlay` matched LainDOS returning `AX=0001` from the previously stubbed `AH=4Bh` handler.

### Fixes Made During Investigation

- Added `scripts/build_mi2.py` and 2.88 MB FAT12 geometry support in `scripts/mkimage.py`.
- Fixed `src/boot.asm` to load every sector in a FAT cluster instead of assuming one sector per cluster.
- Added `INT 21h AH=40h` std-handle write support for runtime error output and `src/writetest.asm` coverage.
- Added a DOS environment executable path via `init_environment`, allowing MI2 to derive `MI2DEMO.000` instead of `.000`.
- Replaced fixed-buffer MZ relocation saving in `setup_exe_dyn` with in-place relocation before copy-down; removed `reloc_buf`.
- Added `src/bigreloc.asm` plus `scripts/test_bigreloc.py` to cover EXEs with more relocation entries than the old buffer.
- Added `INT 21h AH=0Bh` stdin status and `AH=08h` direct character input via BIOS `INT 16h`; added `src/keytest.asm` and `scripts/test_keyboard.py` for no-key status coverage.
- Implemented `AH=58h` get/set return behavior correctly and added first/best/last fit allocation paths. Tiny default allocations now use high placement to avoid blocking immediate PSP regrowth.
- Extended `src/memtest.asm` with last-fit allocation strategy coverage.
- Added minimal `INT 21h AH=4Bh AL=03h` overlay loading for MZ overlays: copy the image portion to the caller-provided load segment and apply relocations using the caller-provided relocation factor.
- Added `src/ovltest.asm`, `src/overlay.asm`, and `scripts/test_overlay.py` to verify overlay load and relocation behavior.

### Tests And Probes Run

- `python3 scripts/build_mi2.py` creates `build/mi2.img` at 2,949,120 bytes.
- MI2 timed serial boot after relocation fix no longer reports `R6000`, `R6001`, or unhandled DOS calls.
- Trace build command used during investigation: `nasm -DTRACE_DOS=230 -DBOOT_FILE='"MI2DEMO EXE"' -f bin src/kernel.asm -o build/mi2_trace_kernel.bin` followed by `scripts/mkimage.py --format=2880k ...`.
- Before the overlay fix, QEMU monitor key injection after the sound warning only cleared the text error screen and did not represent normal DOSBox behavior.
- After the overlay fix, MI2 no longer prints `Error 1 loading sound overlay`; serial output reaches the normal `INT 33h AX=0005` / `AX=000B` mouse polling loop.
- Framebuffer capture after the overlay fix rendered the MI2 demo scene (`/var/folders/_k/0yhtrj754g59m75jw73827q80000gn/T/opencode/mi2-overlay-screen.png`).
- `make test` passed, including boot/memory, big relocation, and keyboard status regressions.
- `make test` passed again after adding overlay coverage.

### Follow-Ups

- Run MI2 in interactive graphical QEMU to verify mouse movement/clicking in the rendered scene.
- Consider replacing the tiny-allocation high-placement heuristic with a more precise DOS-compatible memory behavior if a reference run identifies the exact expected allocator layout.

## 2026-05-22 Shell EXEC Return Crash

### Symptom

- The first shell regression booted `SHELL.COM`, accepted `hello`, and ran `HELLO.COM`, but typing `exit` ended with `EXC 06 at 0140:54E5` instead of returning to the kernel halt path.

### Confirmed Facts

- The shell launched `HELLO.COM` successfully through `INT 21h AH=4Bh AL=00h`; serial output included `PASS: HELLO.COM` and then returned to the shell prompt.
- `do_terminate` uses the global `saved_sp` to return to `exec_com.back`.
- Nested `exec_com_dyn` overwrote `saved_sp` with the child return stack pointer, so the parent shell later exited through stale child EXEC state.
- Adding `DIR` exposed a separate shell bug: after `FindNext`, `ES` no longer pointed at the shell segment, and `read_line` used `STOSB` without first setting `ES=DS`, so later typed commands were written to the wrong segment while comparisons still saw the old `DIR` buffer.

### Fixes Made During Investigation

- Saved the parent's `saved_sp` before nested EXEC and restored it in `restore_exec_parent` after the child returned.
- Added `scripts/test_shell.py` to boot `SHELL.COM`, send `hello` and `exit` through QEMU monitor key injection, and assert the child output plus clean final return.
- Added basic `DIR` support over `FindFirst/FindNext`, wildcard name matching for `*.*`, real DTA filename formatting, `FindNext` `ES:DI` preservation, and shell-side `ES=DS` setup before `STOSB` buffer writes.
- After review, replaced the single-global nested EXEC return state with stack-saved parent state and changed termination restore from `SP`-only to `SS:SP`.
- Added `src/exectest.asm` so the shell regression covers nested EXEC (`SHELL.COM` -> `EXECTEST.COM` -> `HELLO.COM`).
- Fixed COM allocation-size arithmetic to carry through `DX`, cleared `AH=4Dh` return code after retrieval, and skipped deleted/volume-label entries in wildcard directory searches.
- Added basic DTA search-state fields for FindFirst and made volume-label filtering depend on the search attribute mask.

### Tests Run

- `python3 scripts/test_shell.py` passed after the fix.
- `make test` passed, including the new shell regression.
- `python3 scripts/test_shell.py` passed again after adding `DIR`, bad-command, repeated child EXEC, and nested EXEC coverage.
- `make test` passed again after the review fixes.
- `python3 scripts/test_shell.py` and `make test` passed again after DTA search-state and volume-attribute-mask adjustments.
- `python3 scripts/build_mi2.py` rebuilt `build/mi2.img`; a 15-second QEMU serial smoke found `MiniDOS booted` and `EXE loaded` with no `EXC `, runtime error, unhandled `INT 21h`, or `Error 1 loading sound overlay` markers.
- `python3 scripts/build_monkey.py` rebuilt `build/monkey.img`; a 15-second QEMU serial smoke found `MiniDOS booted` and `EXE loaded` with no `EXC `, runtime error, unhandled `INT 21h`, or `File not found` markers.

## 2026-05-22 Shell EXE Launch And VGA Console

### Symptoms

- The shell could launch COM programs but could not launch `HELLOEXE.EXE` by basename because command lookup only tried `.COM`.
- After adding child MZ execution, a shell image containing Monkey Island crashed immediately after `midemo` with `EXC 06 at A000:8000`.

### Confirmed Facts

- `python3 scripts/test_shell.py` failed as expected before implementation: `HELLOEXE.EXE` appeared in `DIR`, but `helloexe` printed `Bad command or file name`.
- The shell-launched Monkey crash happened before DOS trace output or `INT 33h` initialization, so it was in EXE startup/unpacking rather than later file I/O.
- The shell COM MCB was small, but `exec_com_dyn` had set `SP=FFFEh`, placing the parent shell stack in free memory later reused by the large child EXE load.
- After moving COM stacks inside their allocated MCB and adding a small COM stack margin, shell-launched Monkey reached `INT 33h AX=0000` without `EXC `.
- User confirmed the earlier direct-boot Monkey build played PC speaker audio in 86Box, so PIT/speaker passthrough behavior is sufficient there.

### Fixes Made During Investigation

- Added dual console output: DOS `AH=02h` and `AH=09h` still write serial, and now also update VGA text memory at `B800h` with cursor and scroll handling.
- Clear VGA text memory during kernel startup so BIOS boot messages do not remain behind the shell prompt.
- Routed std-handle `AH=40h` writes through the same serial+VGA console path after review.
- Added child `EXEC` support for MZ EXE files by reusing the dynamic MZ setup/relocation path and copying the command tail into the child PSP.
- Updated the environment executable path before child execution so games deriving data filenames from the executable path see the launched program name.
- Changed no-extension shell lookup to try `.COM` first and `.EXE` second.
- Increased COM allocation padding and set COM `SP` to the top of the allocated block instead of `FFFEh` unconditionally.
- Allocated a full fitting free MCB for child EXE loads, matching EXE `maxalloc=FFFFh` expectations closely enough for Monkey/MI2 shell launches.

### Tests Run

- `python3 scripts/test_shell.py` passed with `HELLOEXE.EXE` fallback and child EXE execution coverage.
- `make test` passed.
- `python3 scripts/test_shell.py` and `make test` passed again after routing `AH=40h` std-handle output through the console path.
- `python3 scripts/build_monkey.py` plus a 15-second direct Monkey serial smoke passed.
- `python3 scripts/build_mi2.py` plus a 15-second direct MI2 serial smoke passed.
- Built `build/shell_monkey.img` and launched `midemo` from `SHELL.COM`; a 15-second serial smoke reached `INT 33h AX=0000` with no `EXC `, unhandled `INT 21h`, or `File not found` markers.
- Built `build/shell_mi2.img` and launched `mi2demo` from `SHELL.COM`; a 15-second serial smoke had no `EXC `, runtime error, unhandled `INT 21h`, or sound overlay error markers.
- Captured a QEMU VGA screendump for `build/shelltest.img` at `/var/folders/_k/0yhtrj754g59m75jw73827q80000gn/T/laindos-shell-vga.ppm` to confirm a graphical display surface exists for shell output.
- After adding startup clear, `python3 scripts/test_shell.py` and `make test` passed; a QEMU monitor memory check at `0xB8000` confirmed VGA text starts with `LainDOS Shell` instead of BIOS output.

## 2026-05-22 DOS Console API Completion

### Confirmed Facts

- Phase 12 still lacked `INT 21h AH=01h`, `06h`, `07h`, and `0Ah`, and the shell was still reading command lines with BIOS `INT 16h` directly.
- A new `CONSOLE.COM` regression failed before implementation on unhandled `INT 21h AH=06h`, confirming the test covered the missing DOS path.

### Fixes Made During Investigation

- Added `INT 21h AH=01h` read character with echo.
- Added `INT 21h AH=06h` direct console I/O, including nonblocking input with ZF set on no character and clear on input.
- Added `INT 21h AH=07h` direct character input without echo.
- Added `INT 21h AH=0Ah` buffered line input with basic backspace editing and CR termination.
- Switched `SHELL.COM` line input to `AH=0Ah` and kept command parsing on its NUL-terminated copy.
- Added `src/consoletest.asm` and `scripts/test_console.py`; wired the console test into `make test`.
- After review, preserved `BX/CX` in `AH=01h`, ignored extended-key NUL prefixes in `AH=0Ah`, and extended `CONSOLE.COM` to cover `AH=06h` output.

### Tests Run

- `python3 scripts/test_console.py` passed.
- `python3 scripts/test_shell.py` passed after switching the shell to `AH=0Ah`.
- `make test` passed with the new console regression included.
- `python3 scripts/build_monkey.py` plus a 15-second direct Monkey serial smoke passed, reaching `INT 33h AX=0000`.
- `python3 scripts/build_mi2.py` plus a 15-second direct MI2 serial smoke passed.
- `python3 scripts/test_console.py`, `make test`, and direct Monkey/MI2 serial smokes passed again after the review fixes.

## 2026-05-22 Minimal Shell Built-Ins

### Confirmed Facts

- Phase 10 still lacked `CD`, `TYPE`, `CLS`, and `MEM` in `SHELL.COM`.
- `CD MIDEMO` works through DOS `AH=3Bh` with the existing FAT subdirectory image support.
- `TYPE` can use DOS `AH=3Dh`, `AH=3Fh`, `AH=40h`, and `AH=3Eh` without kernel-specific file access.
- `CLS` needed a DOS-output path that updates the kernel VGA cursor state; shell-side BIOS clearing would leave the kernel console cursor stale.

### Fixes Made During Investigation

- Added command/argument matching in `SHELL.COM` while preserving `.COM` then `.EXE` fallback for external commands.
- Added `CD`, `TYPE`, `CLS`, and `MEM` built-ins.
- Made the shell prompt display the current directory via `AH=47h`.
- Added form-feed handling in `console_putchar` so `CLS` clears VGA text and resets the kernel cursor.
- Added root-path handling to DOS `AH=3Bh` for `CD \`-style paths.
- Made the default `Makefile` build `build/subtest.dat` explicitly instead of depending on a stale generated file.

### Tests Run

- `python3 scripts/test_shell.py` passed with coverage for `CLS`, root `TYPE`, `MEM`, `CD MIDEMO`, subdirectory `DIR`, subdirectory `TYPE`, and `CD /` back to root.
- `make test` passed.
- `python3 scripts/build_monkey.py` plus a 15-second direct Monkey serial smoke passed, reaching `INT 33h AX=0000`.
- `python3 scripts/build_mi2.py` plus a 15-second direct MI2 serial smoke passed with no serial failure markers.

## 2026-05-22 Save-Write FAT Bring-Up

### Confirmed Facts

- Phase 9 had no regular file create/write path: `AH=3Ch` was unhandled and `AH=40h` returned access denied for non-stdio handles.
- A new `SAVEWR.COM` regression failed before implementation at `INT 21h AH=3Ch`, confirming the test covered the missing API path.
- Root-directory save files are enough for the current direct-boot Monkey image layout; subdirectory create/rename/delete remains Phase 13 territory.

### Fixes Made During Investigation

- Added `write_sector` using BIOS `INT 13h AH=03h` with the same CHS geometry and retry path as reads.
- Added FAT12 mutation helpers for setting entries, allocating clusters, freeing a chain on create/truncate, and flushing both FAT copies.
- Expanded file-handle metadata to track directory entry LBA/offset and date/time fields.
- Added root-directory `AH=3Ch` create/truncate, close-time directory size/cluster flush, regular-handle `AH=40h` sequential writes, `AH=56h` root rename, and `AH=57h` get/set file date/time.
- Added `src/savewr.asm` and `scripts/test_savewrite.py`; the test writes a 700-byte pattern across two clusters, closes, reopens, verifies date/time and contents, renames the file, and verifies the mutated disk image on the host.
- Added root-directory `AH=41h` delete with FAT chain freeing and extended `SAVEWR.COM` to delete the renamed file, verify it no longer opens, create a replacement file, and verify the replacement persists on disk.
- After review, changed delete ordering to flush the deleted directory entry before freeing FAT clusters, rejected read-only files, and rejected deletion while a matching file handle is still open.

### Tests Run

- `python3 scripts/test_savewrite.py` failed before implementation on unhandled `AH=3Ch` and passed after the write path was added.
- `make test` passed with `scripts/test_savewrite.py` wired into the ladder.
- `python3 scripts/build_monkey.py` plus a 15-second direct Monkey serial smoke passed, reaching `INT 33h AX=0000`.
- `python3 scripts/build_mi2.py` plus a 15-second direct MI2 serial smoke passed with no serial failure markers.
- `python3 scripts/test_savewrite.py`, `make test`, and direct Monkey/MI2 serial smokes passed again after the review fixes.
- `python3 scripts/test_savewrite.py` failed before delete support on unhandled `AH=41h`; after implementation, `python3 scripts/test_savewrite.py`, `make test`, and direct Monkey/MI2 serial smokes passed.
- `python3 scripts/test_savewrite.py`, `make test`, and direct Monkey/MI2 serial smokes passed again after the delete review fixes.

### Follow-Ups

- Phase 9 remains open until actual Monkey save/load is verified interactively.
- General writable FAT work still needs subdirectory create/write/rename/delete support, directory extension, and seek-gap zero filling.

## 2026-05-22 Shell Monkey Save Probe

### Confirmed Facts

- `scripts/build_shell_monkey.py` rebuilds `build/shell_monkey.img` with current `SHELL.COM`, preserving the on-disk `SHELL.COM` filename while using isolated intermediate build paths.
- The shell-boot Monkey image launches `midemo` from the shell and reaches the playable scene.
- Sending `F5` during the intro and again after skipping to the playable scene did not open a save/load dialog or produce save-related DOS calls.
- The bundled `vendor/readme` identifies this as an interactive contest demo and documents movement plus `Control-C` to exit, but does not document save/load controls.

### Tests And Probes Run

- Built `build/shell_monkey.img` with `python3 scripts/build_shell_monkey.py`.
- Used QEMU HMP key injection to launch `midemo`, send `Esc` to reach the playable scene, send `F5`, and capture screenshots.
- Captured playable-scene screenshot at `/var/folders/_k/0yhtrj754g59m75jw73827q80000gn/T/opencode/monkey-save-probe2.png`.

### Follow-Ups

- Actual Monkey save/load validation likely needs a full game install or a demo build that exposes save/load, not the bundled contest demo.
- Continue writable FAT work with automated DOS API regressions until interactive save/load media is available.

## 2026-05-22 Subdirectory FAT Writes

### Confirmed Facts

- The first subdirectory write regression failed at `AH=3Ch` after `CD MIDEMO`, confirming create/write support was still root-only.
- Existing handle metadata and close-time directory flushing were already sufficient for subdirectory file handles once create/open/delete/rename recorded the subdirectory sector LBA and entry offset.

### Fixes Made During Investigation

- Extended `SAVEWR.COM` to `CD MIDEMO`, create `SUBSAVE.DAT`, write and read back a 700-byte pattern, rename to `SUBDONE.DAT`, delete it, then create `SUBUSED.DAT`.
- Extended `scripts/test_savewrite.py` to include a `MIDEMO` directory in the test image and host-verify `MIDEMO/SUBUSED.DAT` persisted with the expected contents.
- Generalized file create/delete/rename from root-only paths to bare filenames in the current directory, including subdirectory sector lookup and flushing.
- Added subdirectory free-entry scanning for existing directory clusters; directory extension remains deferred.
- Review fix: made subdirectory free-slot search return a real entry index instead of the `loop` counter remainder.
- Review fixes: preserve `AX` across subdirectory directory-sector flushes, and host-check that `SUBSAVE.DAT` is absent after rename.
- Review coverage: `SAVEWR.COM` now checks unsupported multi-component create fails, confirms `SUBTEST.DAT` survived subdirectory mutations, and `CD \` restores access to root files.

### Tests Run

- `python3 scripts/test_savewrite.py` failed before implementation at `FAIL: CREATE` after `CD MIDEMO`, then passed after subdirectory support was added.
- `make test` passed.
- Rebuilt direct and shell-boot Monkey/MI2 images with current scripts.
- Direct Monkey and MI2 serial smokes passed.
- Shell-launched Monkey and MI2 serial smokes passed.
- After review fixes, reran `python3 scripts/test_savewrite.py`, `make test`, rebuilt game images, and reran direct/shell Monkey and MI2 serial smokes; all passed.

### Follow-Ups

- Directory extension is still not implemented; subdirectory writes require an existing free entry in an existing directory cluster.
- Multi-component write paths such as `MIDEMO\FILE.DAT` remain unsupported; callers can `CD MIDEMO` and use bare filenames.
- Seek-past-EOF zero filling remains deferred.

## 2026-05-22 Multi-Sector Subdirectory Scan

### Confirmed Facts

- User reported an interactive save attempt produced a working record file. Exact game save/load semantics are still not fully classified, but this confirms writable game-side file creation is working in practice.
- `find_in_dir` and `find_dir_free` only scanned the first sector of each subdirectory cluster, which is incomplete for 2.88 MB images where `sec_per_clus=2`.
- After changing `SAVEWR`'s regression image to 2.88 MB and preloading 14 filler files before `SUBTEST.DAT`, the first subdirectory sector was full and `python3 scripts/test_savewrite.py` failed at `FAIL: CREATE` before the scanner fix.

### Fixes Made During Investigation

- Updated `scripts/mkimage.py` to write a full cluster of directory entries for subdirectories instead of truncating subdirectory contents at one sector.
- Updated `scripts/test_savewrite.py` to build the save-write regression image as 2.88 MB, force `SUBTEST.DAT` and `SUBUSED.DAT` into the second directory sector, and host-verify that layout.
- Updated subdirectory lookup and free-slot scanning to walk every sector in each directory cluster before following the FAT chain.
- Review fixes: re-establish `ES=SEC_BUF` after subdirectory free-slot sector reads, and generate exact FAT `.` / `..` subdirectory entry names in `mkimage.py`.

### Tests Run

- `python3 scripts/test_savewrite.py` reproduced the bug before the kernel fix with `FAIL: CREATE`.
- `python3 scripts/test_savewrite.py` passed after the scanner fix.

### Follow-Ups

- Directory extension is still not implemented; subdirectory writes require an existing free entry in an existing directory cluster.
- Seek-past-EOF zero filling remains deferred.
- Multi-component write paths such as `DIR\FILE.DAT` remain unsupported.

## 2026-05-22 Multi-Component Write Paths

### Confirmed Facts

- Adding a root-launched regression that creates `MIDEMO\PATHSAVE.DAT`, renames it to `MIDEMO\PATHDONE.DAT`, reads it back, and deletes it failed at `FAIL: CREATE` before the write-path parser was generalized.

### Fixes Made During Investigation

- Reworked `parse_root_path` so write APIs resolve the parent path up to the final separator, then parse the final 8.3 filename component.
- `AH=3Ch` create/truncate, `AH=41h` delete, and `AH=56h` rename now accept multi-component paths while preserving same-directory-only rename behavior.
- Extended `SAVEWR.COM` and host verification to ensure the multi-component test files do not remain after rename/delete.

### Tests Run

- `python3 scripts/test_savewrite.py` reproduced the multi-component create failure before the implementation and passed after parent-directory resolution was added.

### Follow-Ups

- Actual Monkey load validation remains open.

## 2026-05-22 Full VGA Monkey Island Image

### Confirmed Facts

- `vendor/monkey_full.zip` contains 11 files totaling 4,534,333 bytes: `MONKEY.EXE`, `DISK01.LEC` through `DISK04.LEC`, LFL files, and `passwd.txt`.
- The full VGA files do not fit in the existing 2.88 MB floppy format.
- A 10 MB FAT12 image with 8 sectors per cluster keeps the cluster count within FAT12 limits and fits the full game files.
- Booting the 10 MB raw image as a hard disk works with the existing BIOS-drive boot path: SeaBIOS loads sector 0 as `DL=80h`, LainDOS boots, loads `MONKEY.EXE`, and the full game reaches `INT 33h AX=0000` mouse initialization.
- User verified the full VGA image runs interactively with VGA output. Pressing `F5` did not open the save menu during that run, so real save/load validation remains open under Phase 9.

### Fixes Made During Investigation

- Added an `hd10m` `mkimage.py` format with hard-disk media byte and 20/16/63 CHS geometry.
- Added `scripts/build_monkey_full.py` to extract `vendor/monkey_full.zip` into `build/` and build `build/monkey_full.img` without committing game data.
- Added `scripts/test_monkey_full.py` to build the image, boot it as a hard disk, and assert serial startup markers.
- Added `mise run run-monkey-full` for launching the full VGA image interactively.

### Tests Run

- `unzip -l vendor/monkey_full.zip`
- `python3 scripts/build_monkey_full.py`
- `qemu-system-i386 -drive file=build/monkey_full.img,format=raw -boot order=c -serial stdio -monitor none -nographic`
- `python3 scripts/test_monkey_full.py`

### Follow-Ups

- Investigate the correct full-game save/load key path or missing input behavior if `F5` remains inactive.

## 2026-05-22 Seek Gap Zero Fill

### Confirmed Facts

- A sparse-write regression that deleted a non-zero `STALE.DAT`, reused its freed cluster for `GAP.DAT`, wrote `A`, sought to offset 600, and wrote `Z` failed before the fix with stale non-zero bytes in the gap.
- Host-side verification also detected that `GAP.DAT` was not zero-filled between offsets 1 and 599 before the fix.

### Fixes Made During Investigation

- Added a pre-write zero-fill pass for regular file handles when `H_POS` is beyond `H_SIZE`.
- The zero-fill pass temporarily writes from EOF to the target position using `SEC_BUF`, allocating clusters through the normal write cluster walker, then resumes the caller's original write without counting gap bytes in the returned byte count.
- Extended `SAVEWR.COM` and `scripts/test_savewrite.py` to verify the zero-filled gap through DOS reads and host FAT inspection.
- Review fix: return an error if the first gap-fill cluster allocation fails.

### Tests Run

- `python3 scripts/test_savewrite.py` reproduced the stale-gap failure before the implementation and passed after zero-fill support was added.

### Follow-Ups

- Multi-component write paths such as `DIR\FILE.DAT` remain unsupported.

## 2026-05-22 Subdirectory Extension

### Confirmed Facts

- Increasing the 2.88 MB save-write image to preload 29 filler files puts `SUBTEST.DAT` at the last slot of `MIDEMO`'s initial two-sector directory cluster.
- With the initial subdirectory cluster full, `python3 scripts/test_savewrite.py` failed at `FAIL: CREATE` before directory extension was implemented.

### Fixes Made During Investigation

- Extended `find_dir_free` so a full subdirectory ending at FAT EOC allocates a new cluster, links it from the previous directory cluster, zeroes all sectors in the new directory cluster, flushes the FAT, and returns the first slot of the new cluster.
- Tightened the `SAVEWR` host verification so `MIDEMO/SUBUSED.DAT` must be created beyond the original directory cluster.

### Tests Run

- `python3 scripts/test_savewrite.py` reproduced the full-subdirectory failure before the implementation and passed after directory extension was added.

### Follow-Ups

- Seek-past-EOF zero filling remains deferred.
- Multi-component write paths such as `DIR\FILE.DAT` remain unsupported.

## 2026-05-22 Bochs Full Monkey Launcher

### Confirmed Facts

- Bochs rejects `hd10m` geometry when the declared CHS capacity exceeds the raw image size.
- Exact 40/16/32 geometry starts in Bochs, but QEMU hard-disk boot then fails before LainDOS prints `MiniDOS booted`.
- A 20/16/63 geometry with 20,160 total sectors preserves the QEMU hard-disk boot path and fits Bochs' geometry check.
- Timed-out Bochs runs can leave an image lock behind, so the launcher boots a per-run copy of `build/monkey_full.img` and removes that copy after Bochs exits.

### Fixes Made During Investigation

- Added `scripts/run_monkey_full_bochs.py` to build the full Monkey image, generate `build/monkey_full.bochsrc`, and launch Bochs with SDL2 VGA output by default.
- Added `mise run run-monkey-full-bochs` for interactive Bochs launch.
- Added COM1 file logging and a `--smoke-seconds` mode for bounded non-interactive Bochs startup checks that require the `MiniDOS booted` serial marker.

### Tests Run

- `BOCHS_DISPLAY=nogui python3 scripts/run_monkey_full_bochs.py --smoke-seconds 5`
- `python3 scripts/test_monkey_full.py`
- `mise tasks`
- `git diff --check`

## 2026-05-23 Directory Mutation

### Confirmed Facts

- A new `DIRMUT.COM` regression failed before implementation with unhandled `INT 21h AH=39h` while creating `VISIBLE`.
- `MIDEMO` can be pre-filled so `MIDEMO\MAKEDIR` exercises directory creation in an extended subdirectory cluster.
- `RD` must reload the parent directory sector after scanning the target directory because the emptiness scan uses `SEC_BUF` and can overwrite the parent slot buffer.

### Fixes Made During Investigation

- Implemented `INT 21h AH=39h` create-directory with FAT12 cluster allocation, zeroed directory contents, valid `.` and `..` entries, parent entry flush, and FAT flush.
- Implemented `INT 21h AH=3Ah` remove-directory with directory-attribute checks, current-directory rejection, non-empty rejection, parent entry deletion, cluster-chain free, and FAT flush.
- Added `MD` and `RD` shell built-ins.
- Added `scripts/test_dirmut.py` and `DIRMUT.COM` to verify FindFirst visibility, CD into created directories, duplicate-name rejection, rmdir-on-file rejection, current-directory rejection, empty-directory removal, non-empty rejection, nested directory removal, subdirectory parent creation, valid dot entries including non-root `..`, root-directory-full rejection, and no leaked FAT clusters.

### Tests Run

- `python3 scripts/test_dirmut.py` reproduced missing `AH=39h` before implementation and passed after the directory mutation handlers were added.
- `python3 scripts/test_shell.py`
- `make test`
- `python3 scripts/test_monkey_full.py`

## 2026-05-23 Combined Games Hard Disk Shell Bugs

### Confirmed Facts

- The combined all-games hard disk image needs a larger FAT12-compatible geometry than `hd10m`; it was generated as 40/16/63 with 16 sectors per cluster.
- `CD ..` failed from game subdirectories because path resolution treated `..` as an ordinary dotted 8.3 name rather than the directory entry named `..`.
- Game EXEs in the 20 MB image initially returned `Bad command or file name` because executable loading copied whole FAT clusters. With 8 KB clusters this overran the memory allocated from exact file size calculations.
- After size-limited EXE loading, full MI2 started but searched for `A:\speaker.ims`; the EXEC environment path for a relative launch from a current subdirectory was missing the current directory prefix.
- The MI2 demo and full MI2 directories list correctly under QEMU; no directory-entry corruption was reproduced there.

### Fixes Made During Investigation

- Taught `resolve_path` to resolve `.` and `..` directory entries and updated `CD ..` prompt handling for parent traversal.
- Changed `load_file_direct` to copy only `kfsize` bytes instead of every sector in the file's cluster chain.
- Updated EXEC environment path construction so relative launches from a subdirectory produce paths like `A:\MI2\MONKEY2.EXE`.
- Extended the shell regression to run `HELLOEXE.EXE` from `MIDEMO` and return to root with `CD ..`.

### Tests Run

- Reproduced `CD ..` failure and subdirectory game EXE launch failure on `build/games_hd_all.img` before the fixes.
- Rebuilt `build/games_hd_all.img`; verified `CD MI2DEMO`, `DIR`, `CD ..`, `CD MI2`, `DIR`, and `MONKEY2` under QEMU. Full MI2 reached mouse polling instead of `A:\speaker.ims` failure.
- `python3 scripts/test_shell.py`
- `make test`
- `python3 scripts/test_monkey_full.py`

## 2026-05-23 Full MI2 Overlay Allocation

### Confirmed Facts

- Full MI2 from `build/games_hd_all.img` reached the crack intro, but after pressing Space it printed `Overlay Alloc failed for A:\MI2\speaker.ims`.
- A trace build confirmed the path was resolving and opening correctly; the failure was the subsequent `INT 21h AH=48h` request for `0687h` paragraphs.
- Compact memory trace before the fix showed MI2 resizing its PSP from `2804h` to `23DFh`, allocating the first `SPEAKER.IMS` block at `4B97h`, probing heap sizes, then keeping a final `4DE1h` block at `521Fh`; the later second `0687h` allocation failed.
- The first PSP shrink created a large free MCB, and the second shrink created a `0424h` free MCB immediately before it. `AH=4Ah` did not coalesce that newly freed tail with the following free MCB, leaving avoidable fragmentation exactly before the sound/heap allocation sequence.

### Fixes Made During Investigation

- Updated `INT 21h AH=4Ah` shrink handling to merge the newly-created free tail with the immediately following free MCB when that following block is also free.
- Extended `MEMTEST.EXE` with a shrink-merge regression: allocate A/B/C, free B, shrink A, then require an allocation spanning A's freed tail plus B's free block.

### Tests Run

- Rebuilt a `TRACE_DOS` all-games image and reproduced the failing `ALLOC 0687 FAIL` sequence before the fix.
- After the fix, the trace run moved the first `0687h` sound allocation to `4772h`, completed the larger heap probe without the later `0687h` failure, and continued into mouse polling.
- Rebuilt production `build/games_hd_all.img`; QEMU shell launch sequence `CD MI2`, `MONKEY2`, Space reached repeated `INT 33h AX=0005` / `AX=000B` polling with no `Overlay Alloc failed`, `File not found`, unhandled `INT 21h`, runtime error, or exception markers.
- `python3 scripts/test_boot.py`
- `make test`
- `python3 scripts/test_monkey_full.py`
- `git diff --check`
