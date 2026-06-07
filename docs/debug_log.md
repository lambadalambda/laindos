# Debug Log

Running notes for non-trivial investigations. Keep this updated with symptoms, confirmed facts, failed hypotheses, commands, and next probes.

## 2026-06-05 Standardize Serial QEMU Test Boilerplate

### Symptoms

- Many `scripts/test_*.py` files repeated the same build-image, run-serial-QEMU, and marker-check boilerplate. The pattern reappeared 40+ times across the test suite, making new tests longer than necessary and inviting subtle drift in QEMU arguments or timeouts.

### Confirmed Facts

- Added two helpers to `scripts/testlib.py`:
  - `build_simple_test_image(label, boot_file, programs, ...)` — builds the standard boot + kernel + programs + mkimage dance, with a per-test label for output paths.
  - `run_simple_serial_test(label, boot_file, programs, required=, forbidden=, ...)` — wraps the build, runs the image under QEMU, checks required/forbidden markers, exits non-zero on failure.
- Migrated nine simple tests: `test_dup.py`, `test_attrapi.py`, `test_commit.py`, `test_createapi.py`, `test_compatapi.py`, `test_datetime.py`, `test_dosstruct.py`, `test_dbcs.py`, `test_fcbfind.py`. Each went from ~25-35 lines to 16-24 lines (a ~30% reduction).
- Tests that need monitor interaction (e.g., `test_console.py`, `test_envpath.py`, `test_autoexec.py`) were left as-is — the new helpers cover the simple serial regression case.
- The new helpers are additive; existing `build_nasm_test_image`/`run_serial_image`/`check_markers` stay in place for tests that need finer control.

### Tests And Probes Run

- Each migrated test passes individually.
- `make test` reports `78/78` tests pass.
- `make test-game-smokes` passes (Shell Monkey, Full Monkey, Wolf3D, Ascendancy).

### Closed State

- Simple serial regression tests now fit in under 25 lines. The next test can be written without re-implementing the boot/build/QEMU/marker dance.

## 2026-06-05 Unify FAT12 And FAT16 Boot Sectors

### Symptoms

- `src/boot.asm` (FAT12 floppy) and `src/boot16.asm` (FAT16 hard disk) were two near-identical NASM sources. The 80% of code they shared would drift over time: a fix to the CHS math, retry loop, or FAT chain walk could land in one file but not the other.

### Confirmed Facts

- The two files now collapse into a single `src/boot.asm` with `%if FAT12 / %else / %endif` blocks selecting BPB values, total-sectors handling, fat_next body, and the `cy` size.
- The Makefile and every test/build script that assembled a boot sector pass `-DFAT12=1` or `-DFAT16=1` to the new `src/boot.asm`. The previous `src/boot16.asm` is removed.
- Both boot binaries still assemble to exactly 512 bytes with the `0xAA55` signature. One redundant `xor dx,dx` in the FAT12 mcl calculation was removed, which shortened the code by 2 bytes and shifted the data section up.
- The BPB block, root-dir scan, kernel load, and rs routine are now in one place. The only FAT-specific code is the fat_next body, the BPB values, and a 4-line mcl block (FAT12 uses 16-bit total sectors, FAT16 falls back to 32-bit).

### Tests And Probes Run

- `make test` reports `78/78` tests pass.
- `make test-game-smokes` passes (Wolf3D, Shortline, Ascendancy).
- `python3 scripts/check_docs_sync.py` passes (with the line shifts applied via content-matching).
- `make site` and `deno check` pass.

### Closed State

- A single source file owns the boot flow. Future boot-loader changes (CHS math, retry, FAT walk) need to be made in one place.

## 2026-06-05 Share FAT BPB Constants Across Boot And Kernel

### Symptoms

- `src/boot.asm`, `src/boot16.asm`, and `src/kernel.asm` each carried their own copies of FAT12/FAT16 EOC values (`0x0FF8` / `0x0FFF` / `0x0FF0` and `0xFFF8` / `0xFFFF` / `0xFFF0`) and BPB field offsets (`+0B` bytes/sector, `+0D` sec/cluster, ...). The values were correct but had to be edited in three places if a future FAT or boot-path change ever needed them.

### Confirmed Facts

- New shared include `src/fat_bpb.inc` defines `FAT12_EOC`, `FAT12_EOC_VALUE`, `FAT12_RESERVED`, `FAT12_MASK`, `FAT16_EOC`, `FAT16_EOC_VALUE`, `FAT16_RESERVED` plus the 18 standard BPB field offsets (`BPB_BYTES_PER_SEC` through `BPB_FS_TYPE`).
- `src/boot.asm`, `src/boot16.asm`, and `src/kernel.asm` all `%include "src/fat_bpb.inc"` and use the named constants instead of the magic numbers.
- Both boot sectors still assemble to exactly 512 bytes; `equ` declarations do not generate code, and the immediate operands encode to the same length as the original hex literals.
- MBR partition table offsets at `src/kernel.asm:1003-1009` (`bx+0x1C` / `bx+0x1E`) are NOT BPB fields, so they stay as raw offsets.

### Tests And Probes Run

- `python3 scripts/test_fat16.py`, `test_fat16_bounds.py`, `test_fat16_large.py`, `test_partitioned_fat16.py` all pass.
- `make test` reports `78/78` tests pass.
- `make test-game-smokes` passes (Wolf3D, Shortline, Ascendancy).
- `python3 scripts/check_docs_sync.py` passes (with the BPB-name changes reflected in the doc excerpts).
- `make site` and `deno check docs/site/*.jsx scripts/build_site.jsx` pass.

### Closed State

- All FAT12 and FAT16 thresholds and BPB field offsets now come from a single source. The kernel's BPB validation, FAT-type detection, and root-directory sizing all read through the same named constants the boot sectors use.

## 2026-06-05 Move Docs Source Excerpts To Stable Anchors

### Symptoms

- `scripts/check_docs_sync.py` validates doc excerpts by hardcoded source line numbers. Every commit that touches `src/kernel/exec.inc`, `src/kernel.asm`, or other source files shifts the line numbers, and the docs must be updated in lockstep. Five recent commits all needed line-shift updates in the docs.
- The previous fix (archived `Add Documentation Source Sync Checks` issue) caught the drift but did nothing to prevent it.

### Confirmed Facts

- Anchors are declared in source files as `; @anchor: <name>` on their own line, immediately before the line being anchored. The next non-anchor line is the target.
- Docs reference anchors as `[{a: "anchor_name"}, "content"]` in the `code:` and `hi:` arrays. The checker resolves the anchor to its current line number and validates the content.
- `scripts/resolve_doc_anchors.py` produces a `build/.resolved-docs/` copy of the docs with every anchor replaced by a numeric line number. The source docs in `docs/site/` keep their anchor form.
- `scripts/build_site.jsx` calls the resolver and bundles from `build/.resolved-docs/`. The Makefile `site` target grants the `--allow-run=python3` permission the resolver needs.
- Anchored entries do not shift when nearby code moves. Inserting a comment line into the `alloc_exec_environment` function shifted the non-anchored doc entries, but the four `alloc_exec_environment_start`, `alloc_exec_environment_temp_owner`, `free_exec_environment_start`, and `free_exec_environment_coalesce` entries continued to validate.
- Four anchors were placed in `src/kernel/exec.inc` (around `alloc_exec_environment` and `free_exec_environment`) and used in one `code:` block in `docs/site/page_memory.jsx`. The `hi:` array for the same block also references anchors.

### Tests And Probes Run

- `python3 scripts/check_docs_sync.py` passes with anchors and current line numbers.
- `python3 scripts/resolve_doc_anchors.py --src docs/site --out build/.resolved-docs` resolves 13 source file references and writes the staging copy.
- `make site` runs the resolver and produces `build/site/` with 12 pages.
- `deno check docs/site/*.jsx scripts/build_site.jsx` passes.
- Full verification: `make test` reports `78/78` tests pass.
- Anchor stability test: inserted a comment line into the function, ran the checker. The 4 anchored entries still validated; the non-anchored entries correctly flagged as stale. Reverted the test change.

### Closed State

- `scripts/check_docs_sync.py` accepts `[{a: "..."}, "content"]` entries alongside numeric line numbers.
- `scripts/resolve_doc_anchors.py` produces a `build/.resolved-docs/` staging copy.
- `scripts/build_site.jsx` and the Makefile `site` target resolve anchors before bundling.
- `src/kernel/exec.inc` carries the first four anchors; `docs/site/page_memory.jsx` uses them in the `env_owner_lifecycle` section.
- Adding more anchors to other source files and converting other doc entries to anchors is a mechanical follow-up that no longer requires core infrastructure changes.

## 2026-06-05 Remove Stale setup_exe Loader Path

### Symptoms

- `setup_exe` and `exec_exe` in `src/kernel/exec.inc` are static EXE setup / transfer routines that read the EXE image from `TEMP_SEG` (a single sector buffer) and copy it into the load segment, then run it. The current full-file load path writes the image directly into the prog block, so `TEMP_SEG` no longer holds the EXE header at the time these routines expect it.

### Confirmed Facts

- Initial boot path (`src/kernel.asm:363`) and child EXEC path (`src/kernel/int21.inc:1945`) both call `setup_exe_dyn`, not `setup_exe`.
- `setup_exe` is called only by itself and `exec_exe` (i.e., both functions form an isolated pair with no other callers).
- `setup_exe_dyn` mirrors the same logic but sources the image from `prog_seg + 0x10` (the actual program block) instead of `TEMP_SEG`, matching the current `load_file_direct` flow that fills the prog block.
- `docs/site/data.jsx`, `docs/site/page_dosapi.jsx`, and `docs/site/page_programs.jsx` reference only the `_dyn` variants in their source excerpts, so removing `setup_exe` and `exec_exe` does not require prose changes.

### Tests And Probes Run

- `python3 scripts/test_execenv.py`, `scripts/test_envpath.py`, `scripts/test_envoflow.py`, `scripts/test_mcbcoex.py`, `scripts/test_memrelease.py`, `scripts/test_spawn.py`, `scripts/test_execparam.py`, `scripts/test_overlay.py`, and `scripts/test_badreloc.py` all pass.
- Full verification: `make test` reports `78/78` and `python3 scripts/check_docs_sync.py` passes.
- `src/kernel/exec.inc` shrank from 1335 to 1245 lines (-90 lines: 64 for `setup_exe` plus 24 for `exec_exe` plus 2 blank lines).

### Closed State

- `setup_exe` and `exec_exe` removed. The dynamic `_dyn` variants remain the sole EXE setup / transfer path.

## 2026-06-05 Coalesce MCBs After Failed EXEC Rollback

### Symptoms

- Failed `EXEC` paths in `src/kernel/exec.inc` and `src/kernel/int21.inc` (e.g. env overflow, EXE too large, COM too large, alloc failure, I/O error) call `free_exec_environment` and `free_prog_mcb` to clear MCB owners, but do not coalesce adjacent free blocks. Repeated failed `EXEC` calls leave the env block as a separate free piece, fragmenting the arena.
- The previous fragmentation fix (`docs/debug_log.md:185-208`, `Process Memory Release After Exit`) only coalesces during normal process termination, not during `EXEC` rollback.

### Confirmed Facts

- `free_exec_environment` and `free_prog_mcb` in `src/kernel/exec.inc` previously only zeroed the MCB owner and reset the tracking variables.
- The coalesce helpers `mcb_merge_free_forward` and `mcb_coalesce_all_free` exist in `src/kernel/memory_mcb.inc:114-174`. `mcb_merge_free_forward` is already called by `INT 21h AH=49h` (`src/kernel/int21.inc:1520`) and the TSR cleanup paths (`src/kernel.asm:2239, 2278`).
- The env block is always allocated at a lower segment than the program block, so a free-and-merge of the env block walks forward through the program block once it is freed, restoring the chain.
- `prog_seg` is not reset by `free_prog_mcb`; the next successful `EXEC` overwrites it. Left as a separate concern.

### Tests And Probes Run

- Added `tests/programs/mcbcoex.asm` and `scripts/test_mcbcoex.py`. The parent records `largest` after a test-side 18-para alloc, runs `EXEC` with a custom oversized env (triggering `.env_overflow`), and asserts `largest_after_exec == largest_after_alloc` (merge restores the chain).
- Without the fix: test fails with `FAIL: MCBCOEX LARGEST` (env block stays as a 16-paras free piece, separating the chain).
- With the fix in `free_exec_environment` and `free_prog_mcb` (call `mcb_merge_free_forward` after zeroing the owner): test passes.
- Full verification: `make test` reports `78/78` and `python3 scripts/check_docs_sync.py` passes.

### Closed State

- `free_exec_environment` and `free_prog_mcb` now call `mcb_merge_free_forward` after zeroing the owner, so failed `EXEC` paths leave the arena in the same state as before the allocation.
- `Makefile` `check-docs-sync` was updated to recognize the 4-line shift in `src/kernel/exec.inc` (2 lines added in `free_exec_environment`, 2 in `free_prog_mcb`).

## 2026-06-01 INT 21h IF-On-Return Semantics

### Question

- The Stunt Island compatibility fix makes the `INT 21h` return helpers OR `IFLAG` into the saved user FLAGS word before `IRET`.
- This fixed Stunt Island's post-intro QEMU timer wait, but looked suspicious because a normal x86 `INT` frame preserves the caller's original IF bit for `IRET`.

### Confirmed Facts

- MS-DOS 4.00 source `v4.0/src/DOS/DISP.ASM` switches to a DOS-owned stack and executes `STI` at `REDISP` after the stack is safe, then executes `CLI` in `LEAVEDOS` before restoring the user stack and `IRET`ing.
- That dispatcher does not OR `IF` into the saved user FLAGS word; `IRET` restores the caller's original IF.
- A temporary probe run under `/Users/lainsoykaf/repos/MS-DOS/build/dos40.img` printed direct serial output after `CLI; INT 21h; PUSHF`:
  - `AH30 IF=0`
  - `AH4E IF=0`
- The `AH=4Eh` probe used a successful `FindFirst` against `IFPROBE.COM` on a QEMU `file=fat:rw:` C: drive.
- Current LainDOS still passes `python3 scripts/test_findedge.py`, which intentionally asserts that `FindFirst` returns with IF set after caller `CLI`.

### Conclusion

- Forcing `IF=1` on `INT 21h` return is not MS-DOS 4.00 return-flag fidelity.
- The more faithful DOS behavior is to enable interrupts during safe portions of DOS execution, then preserve the caller's IF on return.
- LainDOS's current `IF=1` return is a pragmatic compatibility shim that compensates for LainDOS running most DOS calls with interrupts disabled; it fixes Stunt Island by allowing the BIOS timer tick to advance after return instead of during the DOS call.

### Next Probes

- Keep the current behavior unless a target breaks from it.
- If replacing it later, first test an alternate model that enables interrupts after switching to a kernel stack and preserves caller IF on return, then rerun Stunt Island and `scripts/test_findedge.py` with updated expectations.
- Document this as a known compatibility deviation, not as real-DOS semantics.

## 2026-05-31 Wolf3D QEMU Sound Probe

### Symptoms

- Wolfenstein 3D startup showed Sound Blaster detected under 86Box but not under QEMU when launched with only `-device sb16`.
- The existing LainDOS default environment already exported `BLASTER=A220 I5 D1 H5 P330 T6`, matching QEMU SB16 defaults, so the first suspect was emulator hardware shape rather than DOS environment setup.

### Confirmed Facts

- `qemu-system-i386 -device sb16,help` reports the expected defaults: base `0x220`, IRQ `5`, low DMA `1`, high DMA `5`, and DSP version `1029`.
- Captured Wolf3D startup screenshots show bare `-device sb16` leaves the Sound Blaster line unchecked, while `-device sb16 -device adlib` makes the Sound Blaster line checked.
- QEMU accepts `-device adlib,audiodev=audio0` and `-device sb16,audiodev=audio0 -device adlib,audiodev=audio0`. Passing an explicit `iobase=0x388` to `adlib` hit a QEMU `portio_list_add` assertion in this local build, so the default AdLib I/O base should be used.
- Source comparison explains the 86Box/QEMU split. QEMU's `hw/audio/sb16.c` only registers SB16 DSP/mixer I/O relative to the SB base (`+4`, `+5`, `+6`, `+0A`, `+0C`) and has no OPL/FM handler in the `sb16` device; QEMU's separate `hw/audio/adlib.c` creates a YM3812/OPL2 device and registers the base, base+8, and fixed `388h` port handlers. 86Box's `src/sound/snd_sb.c:sb_16_init` initializes a YMF262/OPL3 FM driver for the SB16 device itself and, when OPL is enabled by default, registers OPL handlers at the SB base, base+8, and `388h`. So 86Box's Sound Blaster 16 profile includes the FM/OPL side expected by real SB16-class setups, while QEMU requires a second `adlib` ISA device to expose a compatible probe path.
- Current fix direction is targeted QEMU configuration parity: keep the BLASTER string as-is for the SB16 DSP path, keep generic game runs on bare `sb16`, and attach QEMU's separate `adlib` device for Wolf3D where the startup probe requires it.

### Tests And Probes Run

- `python3 scripts/build_wolf3d.py` built `build/wolf3d.img` from ignored local media.
- Manual QEMU screenshot probes compared no sound, bare `sb16`, bare `adlib`, and `sb16+adlib` runs under `build/wolf3d_sound_probe/`; those generated screenshots remain ignored investigation artifacts.
- `python3 scripts/test_wolf3d_smoke.py` passes with Wolf3D using `qemu_sb16_adlib_silent_args()` to attach both `sb16` and `adlib` to QEMU's `none` audio backend.
- `python3 scripts/test_shell_monkey.py` fails with `run-time error R6003 - integer divide by 0` when `adlib` is added to the shared helper, while the same smoke passes with bare `sb16`; this prevents making AdLib part of the generic game sound recipe.
- After scoping AdLib to Wolf3D, `python3 scripts/test_shell_monkey.py`, `python3 scripts/test_wolf3d_smoke.py`, and `python3 scripts/test_ascendancy_smoke.py` pass.
- Final checks pass: `python3 -m py_compile scripts/testlib.py scripts/run_stunt_island.py scripts/package_nightly.py scripts/test_wolf3d_smoke.py scripts/test_shell_monkey.py scripts/test_ascendancy_smoke.py`, `python3 scripts/check_docs_sync.py`, `deno check docs/site/*.jsx scripts/build_site.jsx`, `make site`, `git diff --check`, and `make test`.

## 2026-05-30 Shortline Timer And IRQ1 Triage

### Symptoms

- Local media is present as ignored proprietary archive `vendor/SHRTLINE.zip`.
- The archive contains `SHRTLINE/SL.EXE` and data files. The executable is an MZ program, 148661 bytes, SHA1 `bed66d3f194bc17d7ab15d033b401bc33fd695fd`, with 1651 relocations and a 120688-byte MZ load image.
- A direct-boot `hd10m` repro with the game files at image root initially failed before any visible game screen with `EXC 06 at 0000:000B`.

### Confirmed Facts

- DOS tracing showed Shortline installs a private `INT 08h` handler, then temporarily restores `INT 09h` from an uninitialized zero variable before its own keyboard-vector setup completes.
- QEMU interrupt logging showed the original hard crash path as hardware `INT 09h` delivery while the IVT keyboard vector was `0000:0000`, causing the CPU to execute bytes in the interrupt-vector table and trap on invalid opcode.
- LainDOS now masks PIC IRQ1 while a program sets `INT 09h` to `0000:0000`, saves the previous PIC mask, and restores it when a non-null `INT 09h` vector is installed or the program terminates. `IRQMASK.COM` covers the mask/restore behavior.
- After masking the null keyboard vector, the next failure was Shortline's own `Divide by 0 exit`: its PIT/`INT 08h` calibration reads a private timer counter before and after a short loop, observes zero elapsed ticks under normal unthrottled QEMU, and divides by that zero.
- Running the Shortline repro with QEMU `-icount shift=6,align=off,sleep=off` gives the calibration enough virtual timer progress. With that pacing, Shortline reaches active gameplay; `build/shortline_keys2_screen.png` shows the playfield with trains, money/year/level status, and the in-game status text.

### Tests And Probes Run

- Extracted `vendor/SHRTLINE.zip` into generated `build/shortline_files/`; no proprietary files are tracked.
- Built direct repro images with `nasm '-DBOOT_FILE="SL      EXE"' -f bin src/kernel.asm ...` and `python3 scripts/mkimage.py --format=hd10m ... build/shortline.img build/shortline_files/SHRTLINE/*`.
- Used `TRACE_DOS=500` and QEMU `-d int,cpu` logs to identify the `INT 09h` null-vector crash and the divide-by-zero site in the game's 32-bit division helper after zero elapsed private timer ticks.
- Added `tests/programs/irqmask.asm`, `scripts/test_irqmask.py`, and default `make test` coverage for the IRQ1 null-vector guard.
- Added `scripts/test_shortline_smoke.py` and `make test-shortline-smoke`; the smoke builds a disposable image from `vendor/SHRTLINE.zip`, runs QEMU with `-icount shift=6`, sends repeated title-screen keys, and verifies an active gameplay framebuffer with no `EXC`, unhandled DOS call, or `Divide by 0` marker.
- Focused verification currently passes: `python3 scripts/test_irqmask.py` and `python3 scripts/test_shortline_smoke.py`.

### Closed State

- The LainDOS-specific crash is fixed by masking IRQ1 while `INT 09h` is null. The remaining normal-QEMU `Divide by 0 exit` is an emulator pacing issue in Shortline's private PIT calibration and is handled by the documented Shortline smoke command's `-icount shift=6` QEMU run.

## 2026-05-30 Sokoban Device-Chain Triage

### Symptoms

- Local media is present as ignored proprietary archive `vendor/sokoban.zip`.
- The archive identifies itself as Sokoban shareware by Jim Radcliffe; the executable in the tested archive prints `SokoBan 95`, `ShareWare Version`, and `Copyright 1995 By Jim Radcliffe`.
- A direct-boot generated `hd10m` image reached `EXE loaded` and then left an inactive/black framebuffer before the fix.

### Confirmed Facts

- `SOKOBAN.EXE` is an MZ executable with no relocation entries, header paragraphs `0x20`, minimum allocation `0x0152`, `CS=SS=0x1abb`, `IP=0x0100`, and `SP=0x277e`.
- QEMU monitor sampling found the program in a loop that walks DOS device-driver headers by following each header's first far pointer and comparing the 8-byte name at offset `+0x0A` against anti-debug device names including `SOFTICE`.
- LainDOS's prior `INT 21h AH=52h` support only guaranteed `[ES:BX-2] == MCB_START`; the DOS 3.1-4.x NUL device header at `ES:BX+0x22` fell into unrelated data after the short `dos_list_of_lists` table.
- Sokoban consequently followed bogus far pointers through the IVT and BIOS ROM instead of terminating the device-chain scan at the resident `NUL` header.
- LainDOS now exposes a DOS 3.3-style NUL device header at `list_of_lists+0x22` with next pointer `FFFF:FFFF`, attributes `8004h`, and name `NUL     `.
- After the fix, direct boot reaches the visible Sokoban screen; sending Enter/Space reaches the interactive puzzle view captured in `build/sokoban_after_key_screen.png`.
- The game still emits non-blocking unhandled `INT 21h AH=E9` and `AH=E3` markers during startup, but they do not prevent reaching gameplay in this build.

### Tests And Probes Run

- Added focused coverage to `tests/programs/dosstruct.asm` for the `AH=52h` NUL device header shape. Before the implementation change, `python3 scripts/test_dosstruct.py` failed with `FAIL: DOSSTRUCT LOL NUL NEXT`.
- Rebuilt the generated Sokoban repro with `nasm '-DBOOT_FILE="SOKOBAN EXE"' -f bin src/kernel.asm -o build/sokoban_kernel.bin` and `python3 scripts/mkimage.py --format=hd10m ... build/sokoban.img build/sokoban_files/*`.
- Verified the fixed image under QEMU with VNC screendumps. `build/sokoban_fixed_screen.ppm` reported an active framebuffer, and `build/sokoban_after_key_screen.png` shows an interactive puzzle screen.
- `python3 scripts/test_dosstruct.py` passes after the fix.

### Closed State

- The Sokoban hang was caused by incomplete `INT 21h AH=52h` list-of-lists device-chain data. The local triage issue is closed after the focused regression and gameplay smoke both pass.

## 2026-05-30 Micro Machines 2 Copy-Protection Triage

### Symptoms

- Reported issue: Micro Machines 2 hangs under LainDOS.
- Local media is now present as ignored proprietary archive `vendor/003513_micro_machines_2.7z`.

### Confirmed Facts

- The archive contains four FAT12 floppy images: `disk1.img` through `disk4.img`.
- Disk 1 carries `INSTALL.BAT`, `CFG\INSTALL.EXE`, installer config files, and initial `MM2` data. Disks 2-4 carry additional `MM2` data trees.
- A direct `C:` source-tree install is not representative because the installer returns in `C:\CFG` and the batch then falls through from there. Running `C:\CFG\INSTALL E_INST.CFG` directly and installing to `C:\GAMES` produces a valid installed tree at `C:\GAMES\MM2` with `MM2.EXE`, `DOS4GW.EXE`, `MM2.BAT`, and data directories.
- Launch command from the installed tree is `C:`, `CD \GAMES\MM2`, `MM2`.
- The game starts DOS/4GW 1.97 and reaches a visible manual/code-wheel protection prompt: `USE CURSOR KEYS TO HIGHLIGHT SYMBOL ON REVERSE OF MANUAL AT LOCATION : COLUMN D ROW 12`.
- At the prompt there are no unhandled DOS calls and no CPU exception markers. The captured framebuffer is active and the program is waiting for user input, not hanging in a DOS/filesystem path.
- QEMU monitor sampling at the prompt shows protected mode (`CS=0160`, `EIP=001abc05`) and BIOS tick `0x46c` advancing from `1025136` to `1025171` across a short wait, so timer interrupts are still alive.

### Tests And Probes Run

- Extracted the source disks into generated `build/mm2_vvfat/` using the existing FAT image extractor logic from `scripts/build_extras_hd.py`; proprietary files remain under ignored `build/` and `vendor/` artifacts only.
- Booted `build/shell_monkey.img` with QEMU `file=fat:rw:<repo>/build/mm2_vvfat` attached as `C:` and confirmed `INSTALL.BAT`, `CFG`, and `MM2` are visible from LainDOS.
- Ran `C:\CFG>INSTALL E_INST.CFG`, accepted the first screen, typed `GAMES` at the default `C:\` destination prompt, and pressed Enter at the disk prompts. The generated install created `build/mm2_vvfat/GAMES/mm2/` including `mm2.exe` and `dos4gw.exe`.
- Launched `C:\GAMES\MM2>MM2` and captured `build/mm2_probe/run_mm2_60s.ppm`, showing the copy-protection prompt rather than a dead screen.
- Sampled QEMU monitor state with `info registers`, `x /12i $eip`, and `xp /1dw 0x46c` at the prompt.

### Closed State

- The reported hang is explained as the game's manual/copy-protection challenge. No LainDOS implementation change or regression test is indicated unless a valid manual response still fails to reach gameplay.

## 2026-05-30 Local Extras Hard-Disk Image

### Confirmed Facts

- `vendor/FreeDOS.VHD` already carries a broad `C:\GAMES` tree including FreeDOS games plus Duke3D and Quake, but the local Norton Commander, Civilization, and Stunt Island media are separate ignored archives.
- `vendor/003064_norton_commander.7z` contains three FAT12 floppy images with 82 unique root files.
- `vendor/sid-meiers-civilization-au.zip` contains `1.img` and `2.img`; merging them yields 177 unique Civilization files, so `scripts/mkimage.py` now grows one-level subdirectories across multiple clusters instead of truncating directories after one cluster.
- `vendor/002514_stunt_island.7z` contains six FAT12 floppy images. Their Stunt Island payload is installer-compressed into root plus `RES`, `SETS`, and `VAULT` source directories, so `build/extras_hd.img` includes the installer source reproducibly rather than relying on an old generated `build/STUNTISL` tree.

### Tests And Probes Run

- Added `scripts/build_extras_hd.py` to build `build/extras_hd.img` from the local ignored archives, the existing all-games media, Norton Commander, Civilization, and Stunt Island source disks.
- Added `make extras-hd`, `make run-extras-hd`, `mise run build-extras-hd`, and `mise run run-extras-hd` workflow entries.
- Verification passed: `python3 -m py_compile scripts/mkimage.py scripts/build_extras_hd.py scripts/build_games_hd_all.py`, `make extras-hd`, direct QEMU boot to `C:\>`, attached-shell root listing with `NC`, `CIV`, `INSTALL.EXE`, and `EXTRAS.TXT`, and a `C:\CIV` directory listing that finds `WONDERS2.PIC` beyond the first directory cluster.
- Regression verification after the `mkimage.py` changes passed: `git diff --check`, `make test` (`75/75`), and `make test-game-smokes`.

## 2026-05-30 Spawn And Launcher EXEC Compatibility

### Symptoms

- The open launcher issue still needed a Norton-style or equivalent parent-program repro after the Duke SETUP spawn fix and Quake launch fixes.
- The Norton Commander archive was initially misplaced under `build/`; after moving `003064_norton_commander.7z` into `vendor/`, it became available for a local smoke test.

### Confirmed Facts

- A parent program that opened `SPAWNDAT.TXT` and then `EXEC`ed a child left the child's PSP Job File Table slot 5 marked `FFh` even though the inherited handle was usable through LainDOS's global handle table.
- Before the fix, the focused regression failed with `FAIL: SPAWNCH JFT` followed by `FAIL: SPAWN CHILD`.
- `build_psp` now copies the parent PSP's fixed 20-entry JFT into the child PSP when a parent PSP exists, and keeps the boot/default `0,1,2,3,4,FF...` table for the first loaded program.
- Inherited handles now increment the underlying root handle refcount, and `INT 21h AH=3Eh` treats a close of a parent-owned inherited handle as local to the child PSP so the parent handle stays usable.
- Norton Commander 5.5 startup probes `INT 21h AX=6601h`; LainDOS now reports active/system code page 437 and accepts `AX=6602h` when requested active code page `BX` is 437.

### Tests And Probes Run

- Added `tests/programs/spawn.asm`, `tests/programs/spawnch.asm`, and `scripts/test_spawn.py`.
- `python3 scripts/test_spawn.py` now passes: the child sees inherited `PSP:JFT[5]`, reads `SPAWN` from the inherited file handle, closes it locally, returns success, and the parent observes the shared file position by reading the following `!` byte.
- Added `scripts/test_norton_commander_smoke.py` and `make test-norton-commander-smoke`; the smoke extracts `vendor/003064_norton_commander.7z`, direct-boots `NC.EXE` from a disposable image, and verifies the NC framebuffer is active with no unhandled `INT 21h AH=` trace.
- `python3 scripts/test_compatapi.py` covers `AX=6601h` code-page get behavior, unsupported `AX=6600h`, and accepting `AX=6602h` for `BX=437` without treating `DX` as input.
- Focused verification passes: `python3 scripts/run_tests.py scripts/test_spawn.py scripts/test_execparam.py scripts/test_execenv.py scripts/test_jft.py scripts/test_shell.py -j 4`.
- Full verification passes: `python3 -m py_compile scripts/test_spawn.py scripts/run_tests.py`, `make test` reports `75/75`, `make test-norton-commander-smoke` passes, and `make test-game-smokes` passes the shell Monkey demo, full Monkey, Wolf3D, and Ascendancy smoke tests.

## 2026-05-30 Process Memory Release After Exit

### Symptoms

- External compatibility feedback reported that after finishing some games the system usually needed a reboot because later software complained about insufficient memory.

### Confirmed Facts

- Normal termination (`INT 20h`, `INT 21h AH=00h`, and `AH=4Ch`) already marked MCBs owned by the terminating PSP as free and restored the parent PSP before returning to the EXEC frame.
- The missing piece was coalescing: child environment, program, and child-owned allocation MCBs could become adjacent free blocks after exit, but the largest-free-block query and later allocations still saw them as fragmented pieces.
- `INT 21h AH=49h` and TSR cleanup already had forward-merge behavior; normal process termination did not.
- Added a generic MCB free-block coalescing pass and call it after normal termination releases all blocks owned by the terminating PSP.

### Tests And Probes Run

- Added `tests/programs/memrel.asm`, `tests/programs/memrchld.asm`, and `scripts/test_memrelease.py`. The parent records the largest free block, EXECs a child twice, and verifies the largest block is restored after each child exit.
- The focused regression failed before the fix with `FAIL: MEMREL LEAK` and passes after the coalescing pass.
- Focused related tests pass: `python3 scripts/test_envmcb.py` and `python3 scripts/test_tsr.py`.
- Full verification passes: `make test` reports `74/74`, and `make test-game-smokes` passes the shell Monkey demo, full Monkey, Wolf3D, and Ascendancy smoke tests. The SB16-backed smoke tests now attach the sound card to QEMU's `none` audio backend so automated runs stay silent.

### Closed State

- Normal process termination now restores the large reusable free block after a child exits, including child environment, program, and child-owned allocation MCBs.
- `Repair Spawn And Launcher EXEC Compatibility` remains a separate follow-up for launcher-specific EXEC behavior.

## 2026-05-30 Stunt Island Post-Intro Black Screen

### Symptoms

- After the XMS fix, QEMU reaches `Caching data 15360K in extended memory`, then `DISNEY INTRO REEL 15`, then a black screen.
- User manual comparison with the same image in 86Box progresses further to an image asking `do you want to enter the competition`; mouse movement works there, keyboard `Y`/`N` activates the prompt, but clicking the Yes/No buttons did not activate them before `INT 33h AX=0006h` support.

### Confirmed Facts

- The fresh-boot memory complaint and XMS cache-path startup failure are separate and resolved by the large XMS move fix.
- QEMU's remaining black screen diverged from 86Box, so initial QEMU probes prioritized video/timing and CPU-state differences before changing DOS APIs.
- The 86Box prompt shows that LainDOS and the installed Stunt files can get past the intro on at least one emulator. Keyboard `Y`/`N` works and mouse hover changes the cursor, so the remaining click failure points at mouse button edge delivery rather than video, keyboard, or coordinate scaling.
- QEMU black-screen sampling stopped at `CS:IP=1033:6291`, `EFLAGS=0046` (`IF=0`), `ES=0040`, with BIOS tick `40:6C` frozen. The loop is Stunt code at linear `0x165c1`: `cmpw %es:0x6c,%bx; je 0x165c1`.
- Forcing IF on at the stuck loop with gdb immediately advances QEMU to the same nonblack competition prompt class as 86Box (`stats=(208, 217732)`), proving the black screen is a timer/IF deadlock rather than a rendering failure.
- Breakpoints around the preceding `INT 21h AH=4Eh` showed IF was already clear before the DOS call (`eflags=0x2` at `1033:6227`), but making DOS-style `INT 21h` returns set IF lets the subsequent Stunt timer wait advance.
- Added `FINDEDGE` coverage for successful `FindFirst` returning with IF set even when the caller entered with interrupts disabled; this failed before the compatibility fix with `FAIL: FINDEDGE FIND IF`.
- The built-in mouse driver had press-query support (`INT 33h AX=0005h`) but no release-query support (`AX=0006h`). That matched Stunt's symptom class: hover and keyboard work, but button activation on release has no latched release data to consume.
- Added `AX=0006h` release counters and last-release coordinates for left/right buttons, cleared on reset and consumed the same way as press counters.
- User manual retest with the current kernel confirmed the Stunt competition prompt mouse clicks now activate the prompt.

### Tests And Probes Run

- QEMU `std,retrace=precise` and `cirrus` both reproduced the same `1033:6291` loop with IF clear and pending timer IRQ.
- Real-DOS comparison with MS-DOS 4 plus QEMU `file=fat:rw:` was inconclusive because `STUNT` reported `Error in EXE file`.
- `python3 scripts/test_findedge.py` failed before the IF-return fix and passes after it.
- `python3 scripts/test_xms.py` still passes, including the separate XMS far-call IF-preservation sanity check.
- Disposable patched Stunt image `build/stunt_if_hd.img` with a current `SHELL.COM` kernel reaches a nonblack prompt-like screen by 5s and 15s under QEMU (`stats=(208, 217732)`), instead of the prior black screen (`stats=(1, 0)`).
- `python3 scripts/test_mouse.py` covers reset-time empty press and release queries in the basic mouse API program.
- `python3 scripts/test_mousecb.py` now drives monitor `mouse_move`, `mouse_button 1`, and `mouse_button 0`. It failed before the release-query fix with `FAIL: MOUSECB RELEASEDATA` and passes after the fix.
- `make test` passes `73/73` after adding the release-query coverage, and `make test-game-smokes` still passes the Monkey demo, full Monkey, Wolf3D, and Ascendancy smoke tests.

### Closed State

- The post-intro QEMU black screen is fixed by DOS-return IF compatibility, and the prompt click failure is fixed by mouse release-query support.
- A future scripted Stunt smoke can still be added once proprietary-media handling and generated-image setup are formalized.

## 2026-05-30 Stunt Island Fresh-Boot Memory Triage

### Symptoms

- Reported issue: Stunt Island complains about memory even on a fresh boot.
- With the local Stunt Island media installed into a generated hard-disk image, a fresh direct launch no longer reports a conventional-memory error. The game reaches its extended-memory cache path, then the Disney intro, and then a post-intro black screen.

### Confirmed Facts

- `vendor/FreeDOS.VHD` is present and mounts as `C:` under LainDOS, but `C:\GAMES` contains no Stunt Island directory. The visible game directories include `BOLITARE`, `BOOM`, `FREEDOOM`, `DUKE3D`, and `QUAKE`, among others.
- Workspace globbing found no `stunt`, `STUNT`, `island`, or `ISLAND` game media/install tree outside the issue files.
- The Stunt Island manual lists the requirement as 640K total RAM with 570K free RAM. Its troubleshooting text describes the memory failure as similar to `Not enough memory. Stunt Island requires 570,000 bytes free.`
- A fresh LainDOS shell image with `FREE.COM`/`MEM.COM` reports 640K conventional total, 565K conventional free, and largest executable program size `560 K (574384 bytes)`, both from `A:` and after switching to the attached FreeDOS VHD as `C:`.
- LainDOS is therefore just above a 570,000-decimal-byte threshold but below a strict 570 KiB threshold of 583,680 bytes. With the installed game binary now available, the fresh direct launch does not reproduce the manual's conventional-memory error.
- `vendor/002514_stunt_island.7z` contains six raw 1.44 MiB FAT floppy images. Local generated artifacts under `build/` install those disks into `build/stunt_source_hd.img`; proprietary media and installed files remain untracked.
- The installer runs under LainDOS and produces `C:\STUNTISL`. A fresh direct launch from that directory reaches `Caching data 15360K in extended memory.`
- Disabling XMS in a temporary kernel copy makes Stunt skip the cache path and show `DISNEY INTRO REEL 15`, which isolates the original cache-path failure to LainDOS XMS behavior rather than conventional-memory availability.
- The XMS move handler rejected DWORD move lengths with a nonzero high word. `tests/programs/xmstest.asm` now covers a single 65,536-byte conventional-to-XMS move, independent BIOS readback from the requested XMS physical address, and a 65,536-byte XMS-to-conventional move across the 64K boundary; `scripts/test_xms.py` failed before the DWORD-length fix with `FAIL: XMS MOVE 64K TO` and before the physical-address follow-up with `FAIL: XMS MOVE 64K BIOS CMP`.
- XMS `AH=0Bh` now pre-validates full 32-bit extents and loops through conservative `0xFFFE`-byte BIOS block moves while converting handle-1 offsets to the 1 MiB physical base once per chunk. After the fix, Stunt's XMS-enabled fresh direct launch shows the cache screen, then the same `DISNEY INTRO REEL 15` frame observed on the no-XMS path.
- The larger XMS move code made the EMS-enabled test kernel exceed the old scratch-buffer guard, so the runtime buffers moved to `SEC_BUF=0x0B00`, `READ_CACHE_BUF=0x0B20`, and `ROOT_SEG=0x0B40` while preserving the existing root-buffer guard below `0340:C800`.
- Remaining behavior after the intro is a black screen with no DOS `INT 21h` failure marker. CPU sampling before the XMS fix showed real-mode game code looping with interrupts disabled, so this appears separate from the fresh-boot memory complaint.

### Tests And Probes Run

- `python3 scripts/test_attached_hd_shell.py vendor/FreeDOS.VHD --expect GAMES --timeout 20` passes and confirms the attached VHD root contains `GAMES`.
- QEMU shell probe of `C:`, `CD \GAMES`, `DIR` against `vendor/FreeDOS.VHD` confirms Stunt Island is not installed there.
- Temporary generated `build/stunt_mem.img` with `SHELL.COM`, `FREE.COM`, and `MEM.COM` was used only for memory-report probing.
- `python3 scripts/test_free.py` still passes.
- `python3 scripts/test_xms.py` failed before the XMS DWORD-length fix, failed before the follow-up physical-address fix, and passes after both fixes.
- `python3 scripts/run_tests.py scripts/test_xms.py scripts/test_free.py scripts/test_ems.py` passes after the XMS move and buffer-layout changes.
- `make test` passes `72/72` after the XMS move, physical-address, and buffer-layout changes.
- `make test-game-smokes` passes the shell Monkey demo, full Monkey, Wolf3D, and Ascendancy smoke tests.
- `python3 scripts/test_attached_hd_shell.py vendor/FreeDOS.VHD --expect GAMES --timeout 20` passes.
- Temporary Stunt smoke with a current-kernel `build/stunt_xmsfix_hd.img` shows `Caching data 15360K in extended memory` at 1s and `DISNEY INTRO REEL 15` at 3s, then the separate post-intro black screen.

### Follow-Ups

- Treat any post-intro black-screen work as a separate graphics/runtime investigation; the fresh-boot conventional-memory complaint and XMS cache-path failure are now explained by the XMS move-length compatibility gap.

## 2026-05-30 Civilization 1 FCB Search Startup

### Symptoms

- `CIV` from the local Civilization floppy-image archive reached the game configuration flow, but after startup choices `1`, `1`, `1` it logged unhandled `INT 21h AH=11` and then trapped with `EXC 06`.
- The current repro's configuration menu is readable enough to select video/sound/input options, so the immediate blocker was not text rendering.

### Confirmed Facts

- `vendor/sid-meiers-civilization-au.zip` contains two raw 1.44 MiB FAT floppy images; local repro files were extracted/generated under `build/` only.
- Civilization uses FCB `FindFirst` during startup before it reaches its title/gameplay path.
- Added narrow `INT 21h AH=11h`/`AH=12h` support for current-directory 8.3 FCB searches, including extended-FCB attribute masks. Success returns `AL=00h`, failure returns `AL=FFh`, and the successful DTA receives a drive byte plus the raw 32-byte directory entry.
- After the FCB search support, Civilization reaches the title/menu path and visible new-game gameplay with the starting settler/advisor screen. The smoke showed an active framebuffer and no unhandled `INT 21h AH=` or `EXC ` marker.

### Tests And Smokes Run

- `scripts/test_fcbfind.py` builds `tests/programs/fcbfind.asm` and covers missing-file failure, exact match success, exhausted `FindNext`, wildcard success, and extended-FCB directory attribute-mask matching for FCB search.
- Civilization smoke after the fix reached gameplay with 36 colors and 88456 nonblack pixels in the captured framebuffer.
- Final verification for this round: `python3 scripts/test_fcbfind.py`, `python3 scripts/test_parsefcb.py`, `python3 scripts/test_compatapi.py`, `python3 -m py_compile scripts/test_fcbfind.py scripts/run_tests.py`, `git diff --check`, and `make test` pass. The full ladder reports `72/72`.

## 2026-05-30 Boom And SMMU FreeDoom VHD Triage

### Symptoms

- Running `C:`, `CD \GAMES\BOOM`, `BOOM` from `vendor/FreeDOS.VHD` reached Doom startup in the scripted smoke and then appeared to stall around late status-bar initialization.
- Running `C:`, `CD \GAMES\FREEDOOM\PHASE1`, `SMMU` initially reported `IWAD not found` even with `doom.wad` in the current directory; `SMMU -iwad doom.wad` behaved the same.

### Confirmed Facts

- The VHD contains `C:\GAMES\BOOM\BOOM.EXE` with `DOOM.WAD`, and SMMU FreeDoom under `C:\GAMES\FREEDOOM\PHASE1` and `PHASE2` with `SMMU.EXE`, `SMMU.WAD`, and the expected IWADs.
- SMMU was probing DOS 7 Windows LFN functions (`AH=71h`). Returning a generic function-number error made it continue down the wrong path and miss the IWAD; returning carry set with `AX=7100h` lets it fall back to 8.3 FindFirst/FindNext and find the WADs.
- Added narrow `AH=60h` truename canonicalization for 8.3 paths, `AH=50h/51h` set/get PSP, and `AX=5D06h` DOS swappable-data-area pointer. `COMPATAPI` covers these plus the unsupported-LFN fallback signal.
- SMMU Phase 1 now finds `c:/games/freedoom/phase1/doom.wad`, adds `doom.wad` and `smmu.wad`, reaches `V_InitGraphics: Trying driver: 'dos allegro'`, enters protected mode, and shows an active framebuffer with no unhandled `INT 21h AH=` trace and no `EXC ` marker.
- SMMU Phase 2 now finds `c:/games/freedoom/phase2/doom2.wad`, adds `doom2.wad` and `smmu.wad`, reaches the same protected-mode graphics startup point, and shows an active framebuffer with no unhandled `INT 21h AH=` trace and no `EXC ` marker.
- Boom now reaches `I_InitSound`, `S_Init`, `HU_Init`, and `ST_Init: Init status bar.` with an active framebuffer and no unhandled `INT 21h AH=` trace or `EXC ` marker.
- User interactive reproduction after the compatibility slice reports both Boom and FreeDoom run fine. The earlier Boom/SMMU "stall" interpretation was a scripted-smoke false positive: the smoke timed out after serial output stopped while the program was still alive in graphics/runtime code.

### Tests And Smokes Run

- `python3 scripts/test_compatapi.py` covers `AH=50h`, `AH=51h`, `AH=60h`, `AX=5D06h`, and unsupported `AH=71h`; it passes.
- QEMU SMMU Phase 1 smoke with `build/shell_monkey.img` plus `vendor/FreeDOS.VHD` attached with `-snapshot`: no `IWAD not found`, no `EXC `, no unhandled `INT 21h AH=`, framebuffer active with 41 colors and 255600 nonblack pixels.
- QEMU SMMU Phase 2 smoke: no `IWAD not found`, no `EXC `, no unhandled `INT 21h AH=`, framebuffer active with 178 colors and 253824 nonblack pixels.
- QEMU Boom smoke: no `IWAD not found`, no `EXC `, no unhandled `INT 21h AH=`, framebuffer active with 138 colors and 256000 nonblack pixels; serial progress remains at `ST_Init: Init status bar.` during the longer probe.

### Follow-Ups

- If Boom or SMMU regress again, capture the exact command line, input sequence, framebuffer, and serial output before treating it as a new DOS API blocker.

## 2026-05-30 Duke Nukem 3D SETUP Spawn Error

### Symptoms

- Running `C:`, `CD \GAMES\DUKE3D`, `SETUP` from `vendor/FreeDOS.VHD` failed with `DOS/16M error: [8] cannot open file ''` and `Spawn Error: Error 0`.
- Running `SETMAIN` directly reached the Duke Nukem 3D setup UI, so the blocker was in the launcher/spawn path rather than the setup payload itself.

### Confirmed Facts

- A temporary `TRACE_DOS` EXEC probe showed `SETUP.EXE` calls `EXEC .\setmain.exe` with a caller-provided environment segment.
- The spawned DOS/4GW child needs an environment executable-path tail for the child executable. Reusing the caller-provided environment block unchanged left the child with no useful path tail and caused the empty-file DOS/16M error.
- `EXEC` now copies caller-provided environment variables into a child-owned environment block and appends the launched executable path tail, while leaving the caller's original environment MCB owned by the caller.
- `AX=6300h` now returns an empty DBCS lead-byte table so DOS/4GW/Duke setup does not log an unhandled `INT 21h AH=63` probe on single-byte code page setups.
- Residual risk: environment blocks are still fixed at 16 paragraphs; a future caller with a large custom environment may need variable-sized environment allocation or an overflow guard.

### Tests And Smokes Run

- `python3 scripts/test_execenv.py` now covers a caller-provided environment with a dot-relative child path and verifies the child sees `A:\ENVCHILD.COM` in the environment path tail.
- `python3 scripts/test_dbcs.py` covers `AX=6300h` empty DBCS table behavior and unsupported `AX=6301h` failure.
- `python3 scripts/test_envpath.py` still passes.
- QEMU smoke with `build/shell_monkey.img` and `vendor/FreeDOS.VHD`: `C:`, `CD \GAMES\DUKE3D`, `SETUP` reaches the Duke Nukem 3D setup UI with no `DOS/16M error` and no unhandled `INT 21h AH=` trace.

## 2026-05-30 BLASTER Environment Variable

### Confirmed Facts

- Some games, including Quake during startup, check the DOS `BLASTER` environment variable before probing Sound Blaster hardware.
- LainDOS now adds `BLASTER=A220 I5 D1 H5 P330 T6` to the default MCB-backed environment alongside `COMSPEC`, `PATH`, and `PROMPT`.
- The values match the SB16 portion of the common QEMU game-sound configuration: base `220h`, IRQ `5`, low DMA `1`, high DMA `5`, MPU `330h`, and SB16 type `T6`.

### Tests Run

- `python3 scripts/test_envpath.py` failed before the fix with `FAIL: ENVTEST BLASTER`.
- `python3 scripts/test_envpath.py` passes after the fix.

## 2026-05-30 Quake From FreeDOS VHD

### Symptoms

- `QUAKE.EXE` from `vendor/FreeDOS.VHD` was visible in `C:\GAMES\QUAKE`, but launching `QUAKE` initially returned `Bad command or file name`.
- After the EXE loader accepted the file, Quake's stub printed `Load error: no DPMI` because `CWSDPMI.EXE` needed TSR termination support.
- After TSR support, Quake detected DPMI and loaded the protected-mode image, but failed at `Error fstating c:/games/quake/id1/pak0.pak`.

### Confirmed Facts

- `QUAKE.EXE` is an MZ executable with zero relocations and an unusual relocation-table offset. Relocation-table bounds should not reject a zero-relocation EXE.
- `CWSDPMI.EXE` calls `INT 21h AH=31h`; handling this requires keeping the requested PSP MCB resident, preserving installed interrupt vectors, freeing non-resident child-owned MCBs, closing owned handles, and returning to the parent EXEC frame.
- DOS4GW/CWSDPMI expects `INT 21h AH=4Dh` to report termination type `AH=03h` after a TSR exit, not just return code `AL`.
- A traced Quake run after the TSR fix opened `c:/games/quake/id1/pak0.pak` successfully as a DOS handle and saw size `011D2CD3`, then the protected-mode runtime used the next handle number during stat cleanup. The missing PSP Job File Table metadata was the discriminator.
- `build_psp` now initializes PSP JFT fields at `18h`, `32h`, and `34h`; open/create/dup/force-dup/close paths keep the fixed 20-entry PSP JFT in sync; `AH=67h` refreshes that fixed metadata while still not expanding beyond `MAX_HANDLES=20`.
- Current Quake smoke reaches visible in-game first-level gameplay after acknowledging sound/CD prompts. Later Boom/SMMU compatibility work added narrow `AH=60h` truename and `AX=5D06h` SDA support, so those probes are no longer expected to log as unhandled calls.

### Tests And Smokes Run

- `python3 scripts/test_badreloc.py` failed before the zero-reloc loader fix with `FAIL: BADRELOC GOOD NORELOC`; it passes after the fix.
- `python3 scripts/test_tsr.py` failed before `AH=31h` support with unhandled `INT 21h AH=31`; after adding TSR return-type coverage it passes.
- `python3 scripts/test_jft.py` failed before PSP JFT initialization with `FAIL: JFT INIT`; it passes after JFT initialization and maintenance.
- `python3 scripts/test_retcode.py` passes after adding TSR return-type state.
- `make test` passed `69/69`.
- QEMU smoke with `build/shell_monkey.img` and `vendor/FreeDOS.VHD` attached as `format=vpc`: `C:`, `CD \GAMES\QUAKE`, `QUAKE` now loads both PAK files and reaches gameplay. Screendumps captured the Quake startup prompts and in-game view.

## 2026-05-30 FreeDOS VHD As Attached C: Disk

### Symptoms

- Booting `build/shell_monkey.img` from `A:` with `/Users/lainsoykaf/Downloads/FreeDOS.VHD` attached as the IDE hard disk left no usable `C:` drive; `C:` printed `Path not found` and the shell stayed at `A:\>`.

### Confirmed Facts

- `qemu-img info /Users/lainsoykaf/Downloads/FreeDOS.VHD` reports `file format: vpc`, virtual size `420 MiB`.
- Reproduced under QEMU with `-drive file=build/shell_monkey.img,format=raw,if=floppy` and `-drive file=/Users/lainsoykaf/Downloads/FreeDOS.VHD,format=vpc,if=ide,index=0,media=disk`.
- Logical sector 0 is an MBR, not a FAT BPB. The active partition entry is type `06` and starts at LBA `63`.
- The partition boot sector at LBA `63` is a FAT16 BPB with OEM `FRDOS5.1`, hidden sectors `63`, and label/type bytes `FREEDOS2025` / `FAT16`.
- The previous floppy-boot C: mount path only accepted a FAT BPB directly at hard-disk sector 0, so it rejected MBR-partitioned hard disks before creating logical `C:`.
- The mount path now falls back to MBR parsing, selects an active FAT12/FAT16 partition or first FAT12/FAT16 partition, reads its VBR, and mounts that BPB as logical `C:`.
- `scripts/test_multidrive.py` now runs the existing direct multi-drive regression against both a raw FAT hard disk and an MBR-wrapped FAT16 attached hard disk whose BPB hidden-sector field is left at zero, covering the kernel's partition-offset fallback.

### Tests And Smokes Run

- `python3 scripts/test_multidrive.py` failed before the fix on the partitioned attached hard disk with `FAIL: MULTIDRIVE SELECT C COUNT`.
- `python3 scripts/test_multidrive.py` passes after the fix for both raw and partitioned attached hard disks.
- `python3 scripts/build_shell_monkey.py`
- QEMU smoke with `/Users/lainsoykaf/Downloads/FreeDOS.VHD` as `format=vpc` now switches from `A:\>` to `C:\>`, lists FreeDOS root entries including `FREEDOS`, `GAMES`, `KERNEL.SYS`, and exits cleanly with `Program exited, code=00` and `HALT`.
- `make test` passed `67/67`.
- Added `scripts/test_attached_hd_shell.py` as a local-only smoke for user-provided hard-disk images. It rebuilds the shell Monkey floppy, attaches the supplied image with QEMU `-snapshot`, runs `C:` and `DIR`, and supports optional `--expect` markers for images such as FreeDOS VHDs.

## 2026-05-29 Floppy Boot With Attached C: Hard Disk

### Symptoms

- Booting `build/shell_monkey.img` as `A:` with `build/games_hd_all.img` attached did not expose the attached hard disk as `C:`.
- The shell also treated a standalone `C:` line as an external command instead of a drive switch.

### Confirmed Facts

- Added `tests/programs/multidrive.asm`, `scripts/test_multidrive.py`, and `scripts/test_multidrive_shell.py` for a floppy boot with a second IDE hard-disk image.
- The first direct regression failed at `FAIL: MULTIDRIVE SELECT C COUNT`, confirming that the kernel only exposed the BIOS boot drive.
- LainDOS now keeps per-drive geometry, BPB, current-directory, and BIOS-drive slots for `A:`/`B:`/`C:` and mounts BIOS `80h` as logical `C:` when booting from a floppy.
- File handles now remember their owning drive, and FindFirst stores the active drive in the DTA so FindNext resumes against the same volume.
- The shell accepts standalone drive-switch commands such as `A:`, `B:`, and `C:`.
- Full `make test` initially exposed a FAT16 hard-disk boot reboot loop. The FAT16 root buffer at `ROOT_SEG=0x0B00` is 16 KiB and ended exactly at the old stack top physical `0x0F000`, so loading the root directory overwrote the active kernel stack.
- Raising `KERNEL_STACK_TOP` to `0xC800` gives the FAT16 root buffer a guard below the stack while keeping the stack below `MCB_START`; a compile-time guard now rejects layouts that leave too little root/stack separation.
- Review follow-up made failed drive switches restore the previous drive geometry and buffers before returning carry set.
- Review follow-up expanded `MULTIDRIVE.COM` to cover interleaved open handles across A:/C:, FindNext continuing on C: after selecting A:, and C: write verification after an A: I/O interlude.

### Tests And Smokes Run

- `python3 scripts/test_drive.py`
- `python3 scripts/test_multidrive.py`
- `python3 scripts/test_multidrive_shell.py`
- `python3 -m py_compile scripts/test_multidrive.py scripts/test_multidrive_shell.py scripts/run_tests.py`
- `git diff --check`
- `python3 scripts/test_drivedata.py`
- `python3 scripts/run_tests.py scripts/test_diskfree.py scripts/test_fat16.py scripts/test_fat16_bounds.py scripts/test_partitioned_fat16.py scripts/test_fat16_large.py scripts/test_badfat.py scripts/test_highdir.py scripts/test_fat16_seek.py scripts/test_multidrive.py scripts/test_multidrive_shell.py`
- `make test` passed `67/67`.
- `python3 scripts/build_shell_monkey.py`
- `python3 scripts/build_games_hd_all.py`
- QEMU acceptance smoke booted `build/shell_monkey.img` as floppy with `build/games_hd_all.img` attached as IDE disk, switched to `C:`, changed to `C:\MI2`, launched `MONKEY2`, observed game startup screen clearing, and saw no `FAIL:`, `EXC `, `INT 21h AH=`, `Bad command or file name`, or returned `C:\MI2>` prompt during the smoke window.

## 2026-05-28 Environment MCB Blocks

### Confirmed Facts

- Added `tests/programs/envmcb.asm` / `tests/programs/envchld.asm` / `scripts/test_envmcb.py`; before the fix it failed with `FAIL: ENVMCB CHILD` because child `PSP:002Ch` pointed below `MCB_START` at the fixed environment block.
- The parent-side regression now walks the MCB chain after the child exits and fails if any block remains owned by a non-parent PSP, covering child environment/program MCB release.
- Environment blocks are now allocated from the MCB arena before program allocation so EXE `MaxAlloc` leaves room for them. `build_psp` stores the allocated segment in `PSP:002Ch` and patches the environment MCB owner to the child PSP.
- The boot program also gets an MCB-backed environment, so `HIGHMCB` now expects the first arena block to be the PSP-owned environment block followed by free space.

### Tests And Smokes Run

- `python3 scripts/test_envmcb.py`
- `python3 scripts/run_tests.py -j 4 scripts/test_envmcb.py scripts/test_envpath.py scripts/test_dosstruct.py scripts/test_shell.py scripts/test_highmcb.py scripts/test_overlay.py scripts/test_regpres.py`
- `make test` passed `44/44`.
- `python3 scripts/test_monkey_full.py` passed.
- Wolf3D QEMU VGA smoke passed with `-vga std,retrace=precise`, `80` colors, and `233588` nonblack pixels.
- Ascendancy QEMU startup smoke passed, reaching `DOS/4GW` and `Ascendancy` banners with `59` colors and `307045` nonblack pixels.

## 2026-05-28 Wolfenstein 3D QEMU VGA Status Stall

### Symptoms

- The standalone `build/wolf3d.img` path under patched QEMU loads `WOLF3D.EXE` but stays on a black framebuffer.
- Serial shows `EXE loaded` with no `EXC ` marker and no unhandled `INT 21h AH=` marker.

### Confirmed Facts

- The all-games hard disk now includes Wolf3D shareware files under `WOLF3D` from `vendor/wolf3dsw.zip`.
- User confirmed the same `build/games_hd_all.img` starts Wolf3D fine in 86Box by running `C:\WOLF3D\WOLF3D.EXE`; it reaches the red hardware detection screen.
- The 86Box screen detects mouse and Sound Blaster and reaches visible UI without EMS/XMS indicators, so XMS/EMS is not the startup blocker for this shareware path.
- A QEMU monitor sample during the black screen lands in a real-mode loop reading VGA status port `0x3DA` with interrupts disabled.
- A standalone VGA status probe shows QEMU's port `0x3DA` value changes while interrupts are enabled and the BIOS tick advances, but remains fixed at `0x09` during a tight `CLI` loop. `-icount shift=auto` did not change that behavior.
- Running Wolf3D under real DOS 4.0 from `/Users/lainsoykaf/repos/MS-DOS/build/dos40.img` in QEMU, with the Wolf3D files exposed as `file=fat:rw:/Users/lainsoykaf/repos/laindos/build/wolf3d_files`, reproduces the same all-black framebuffer hash as the LainDOS/QEMU run: `f3ee47648d6ba080ffab59f9c5cc84d66a44ee6de07c5fa3edbe222e95021062`.
- The real-DOS/QEMU stopped state also has `DX=0x03DA`, `EIP=0x66`, and `IF=0`, so the default-QEMU failure is independent of LainDOS.
- The advisor hypothesis was right about the QEMU-side root class but wrong about which retrace setting would help on this build: explicit `-vga std,retrace=dumb` keeps the `CLI` VGA-status probe stuck at `0x09`, while `-vga std,retrace=precise` makes the probe pass.
- `WOLF3D_VGA='std,retrace=precise' python3 build/run_wolf3d_probe.py` reaches visible Wolf3D output under LainDOS/QEMU: `sha256=3e88b7df9eec9e7c6eebf89b4d7442ea3f0b1a604973e50cb5dbea1633b961bd colors=79 nonblack=233588`.
- `make run` and the interactive mise QEMU run tasks now default to `std,retrace=precise` through `QEMU_VGA` / `LAINDOS_QEMU_VGA`, including `run-games-hd-all`.
- Added minimal XMS support: `INT 2Fh AX=4300h/4310h`, an XMS entry point for version/query/allocate/free/move/lock/unlock/handle-info, and `scripts/test_xms.py`.
- Added minimal EMS support: `EMMXXXX0` device detection plus `INT 67h` status/page-frame/free-pages/allocate/map/free/version/handle-count/page-count behavior, and `scripts/test_ems.py`.
- To make room for the new handlers, moved the sector buffer to `0x0920`, environment to `0x0940`, root buffer to `0x0960`, and kernel stack top to `0340:BC00` (`0x0F000` physical). Boot sectors now load the root directory at the same `0x0960` segment the kernel uses.
- After XMS/EMS support, `WOLF3D_VGA='std,retrace=precise' python3 build/run_wolf3d_probe.py` produces `sha256=8a3e7874915bfd54ded0487c121c3a8ff27bcfb137e7162da3f19f091e8c7fb7 colors=80 nonblack=233588`; the screenshot shows EMS and XMS green through `1000`, while MAIN is green through `288` and dark at `320`.
- `python3 build/run_wolf3d_keyprobe.py` presses through the startup screen and reaches the Wolf3D title screen: `sha256=8de1e718bb13e71876cc2756cb18e6cc1b592b66692c3a183efea5dadd5054f7 colors=135 nonblack=231496`, with no `EXC ` or unhandled `INT 21h AH=` marker.
- Full `make test` passed with the new XMS/EMS tests included: `36/36` in 11.11s.
- XMS `AH=0Bh` now has a backed move path. `scripts/test_xms.py` copies 32 bytes conventional-to-XMS, clears the destination, copies XMS-to-conventional, verifies the round trip, and checks that an out-of-bounds XMS source move fails.
- Full `make test` passed after XMS move support and review cleanup: `36/36` in 10.96s.
- EMS page mapping is now backed. The advertised page frame moved from the non-writable UMA/ROM area to a writable `9000h` conventional-memory window; `INT 67h AH=44h` saves/loads 16 KB pages through `INT 15h AH=87h`.
- `scripts/test_ems.py` now verifies page-frame persistence by writing logical page 0, remapping page 1, then remapping page 0 and comparing the original bytes.
- Reserving the frame from the MCB arena at `8000h`, `8C00h`, or `9000h` made Wolf3D fail with its not-enough-memory screen. The current `9000h` frame is therefore a compatibility window rather than a protected DOS allocation; this preserves Wolf3D's conventional memory but carries a collision risk for programs that also allocate/use that range directly.
- With the unreserved writable `9000h` frame, `python3 build/run_wolf3d_smoke.py` reaches Wolf3D floor 1 with visible wall/floor textures and no `EXC `, `INT 21h AH=`, or `PML_MapEMS` marker. `WOLF_GAME_WAIT=20 python3 build/run_wolf3d_smoke.py` remains stable through the screenshot point.
- Full `make test` passed after EMS backing and review cleanup: `36/36` in 11.09s, kernel `23719` bytes.
- User then reproduced the expected collision risk interactively: one Wolf3D run reached gameplay and then crashed with `EXC 06 at 9999:9CA4` and bytes starting `C5 C8 CA D1...`; a second run did not crash. The bogus `9999` code segment and intermittence match execution through corrupted heap/data, most likely from the unreserved EMS frame overlapping Wolf3D conventional allocations.
- Probed alternate non-MCB frame locations with `LAINDOS_EMS_FRAME_SEG=0xB000/0xC000/0xD000/0xE000 python3 scripts/test_ems.py`; all failed `FAIL: EMS BACKING`, so QEMU does not provide a usable non-overlapping writable upper-memory frame in this configuration.
- EMS is now gated behind `ENABLE_EMS=1` and default builds hide `EMMXXXX0`/`INT 67h`. `scripts/test_ems.py` compiles with `-DENABLE_EMS=1` so the experimental backed implementation remains covered.
- With default EMS hidden and XMS still enabled, `python3 build/run_wolf3d_smoke.py` reaches floor 1 with visible textures. Three repeated short smoke runs reached the screenshot point with no `EXC `, unhandled `INT 21h AH=`, or `PML_MapEMS` marker.
- Full `make test` passed with EMS hidden by default, a safe absent `INT 67h` handler installed, and EMS explicitly enabled only for `scripts/test_ems.py`: `36/36` in 11.42s, default kernel `23137` bytes.
- User reported Ascendancy then failed at startup with `DOS/4GW fatal error (1307): not enough memory` when XMS was enabled. Hiding XMS let Ascendancy reach its previous startup banner, confirming the failure was in DOS/4GW's XMS path.
- Advisors agreed the likely issue was that DOS/4GW commits to XMS when present and expects a realistic memory pool. A discriminator run with the same single-handle implementation but `XMS_TOTAL_KB=8192` fixed the Ascendancy memory error, so the immediate blocker was the old 1 MiB report rather than multi-handle allocation.
- XMS now sizes its single block from BIOS `INT 15h AH=88h`, capped by `XMS_MAX_KB=15360` so the BIOS `AH=87h` move descriptors stay below the 24-bit/16 MiB ceiling. `tests/programs/xmstest.asm` allocates the full capped block under QEMU and verifies an end-of-block bounds rejection at `0x00EFFFF0 + 32`.
- `python3 build/run_asc_probe.py` against `scripts/build_games_hd_all.py` with default XMS enabled reaches the DOS/4GW banner and Ascendancy copyright banner without error 1307.
- `python3 build/run_wolf3d_smoke.py`, `python3 scripts/test_ems.py`, and full `make test` passed after dynamic XMS sizing: `36/36` in 10.80s, default kernel `23171` bytes.
- `FREE.COM` now prints an MS-DOS-style memory table with fixed-width KB columns, and the shell `MEM` command is provided by the same utility built as `MEM.COM`; focused `test_free.py`, `test_shell.py`, `test_xms.py`, `test_ems.py`, `test_boot.py`, and full `make test` passed: `36/36` in 10.92s. Local Ascendancy/Wolf3D probe scripts and vendor archives were not present for rerun in this checkout.

### Follow-Ups

- Treat Wolf3D startup as a QEMU VGA-status/timing issue unless a separate 86Box failure appears. Use `-vga std,retrace=precise` for QEMU Wolf3D runs.
- The current XMS support includes backed `AH=0Bh` moves for a single BIOS-sized/capped allocated block. EMS has a backed single-handle implementation only when built with `ENABLE_EMS=1`; keep it hidden by default until there is a safe non-overlapping frame, UMB support, or a target that can tolerate the `9000h` compatibility window.
- If QEMU support is desired, isolate a minimal `0x3DA`/`IF=0` reproducer for QEMU before changing LainDOS.

## 2026-05-28 Ascendancy QEMU SAHF Root Cause

### Symptoms

- Stock QEMU master and the earlier `floatx80` trig experiment both still froze Ascendancy at the same first Logic Factory framebuffer hash `8e5010bd947253405c00ac7f16d5cb0edf00901e17394d2e567a733b635c61b6`.
- The patched-trig run passed the temporary `FPUTEST`, but full Ascendancy still had no `Thank you for playing Ascendancy.`, no `EXC ` marker, and no visible progress.

### Confirmed Facts

- A stopped monitor sample showed the old stall was not a single endless `FPREM`: the DOS/4GW helper often had `FSW=3820` with C2 clear and should have returned without range reduction.
- Stack sampling identified the repeating caller chain as Ascendancy code around `0x1a26a2`, calling the DOS/4GW `FCOS` wrapper at `0x1c699a`; a higher loop around `0x171c09..0x171cb9` repeatedly called that rotation helper.
- The repeated x87 value `0.739085...` is the fixed point of `cos(x)`, which suggested the wrapper was repeatedly re-running `FCOS` on its own result instead of accepting the first in-range result.
- A new temporary real-mode reproducer, `build/dos4gwtrig.asm` / `build/d4gwtrig.img`, mimics the DOS/4GW helper pattern exactly: `fnstsw [bp-2]`, `mov ah,[bp-1]`, `or ah,1`, `sahf`, `jnp exit`, otherwise `fprem` and `clc`.
- On stock QEMU and on the earlier trig-patched QEMU, that reproducer failed on a clean 10-degree input: `FAIL: DOS4GWTRIG CLEAN COUNT=0041 SW=3800 ENTRY=3800 AX=3800 MEM=3800 FLAGS=0212`.
- `FNSTSW AX` and `FNSTSW [mem]` both reported `0x3800`, so the x87 C2 bit itself was clear. The helper still returned with CF clear because QEMU evaluated the post-`SAHF` `JNP` using stale lazy parity state from the preceding `OR AH,1`.
- In QEMU `target/i386/tcg/emit.c.inc`, `gen_SAHF` updated `cpu_cc_src` but did not switch the lazy condition-code mode to `CC_OP_EFLAGS`.
- Adding `set_cc_op(s, CC_OP_EFLAGS);` at the end of `gen_SAHF` is sufficient for `DOS4GWTRIG` to pass.
- After removing the earlier `floatx80` trig experiment, the isolated one-line `SAHF` fix still passes `DOS4GWTRIG` and `FPUTEST`.
- With only the `SAHF` fix in QEMU, Ascendancy no longer stops at the old hash. The probe reaches framebuffer hash `fe0a77132d945126590a8a506487e7f4a9bbac57946e907b39039ae20c80bc55` and execution is elsewhere (`EIP=001a4115`) rather than in the DOS/4GW x87 wrapper.
- The isolated QEMU patch is saved in this repo as `docs/qemu-sahf-ccop.patch`.

### Tests And Probes Run

- `/Users/lainsoykaf/repos/qemu-ascendancy/build-asc/qemu-system-i386-unsigned -drive file=build/fputest.img,format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic`
- `python3 build/run_asc_stock.py` against stock/patched QEMU before the `SAHF` fix: old stuck hash `8e5010...` at both screenshots.
- `python3 build/run_asc_stock.py` with stopped monitor snapshots and stack dumps around `0x1c696e`, `0x1a26a2`, and `0x171c20`.
- `nasm -f bin build/dos4gwtrig.asm -o build/d4gwtrig.com`
- `nasm '-DBOOT_FILE="D4GWTRIGCOM"' -f bin src/kernel.asm -o build/d4gwtrig_kernel.bin`
- `python3 scripts/mkimage.py build/boot.bin build/d4gwtrig_kernel.bin build/d4gwtrig.img build/d4gwtrig.com`
- `qemu-system-i386 -drive file=build/d4gwtrig.img,format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic` failed before the fix.
- `/Users/lainsoykaf/repos/qemu-ascendancy/build-asc/qemu-system-i386-unsigned -drive file=build/d4gwtrig.img,format=raw,if=floppy -boot order=a -serial stdio -monitor none -nographic` passes after the fix.
- `ninja qemu-system-i386-unsigned` in `/Users/lainsoykaf/repos/qemu-ascendancy/build-asc`.
- `python3 build/run_asc_stock.py` with the isolated `SAHF` fix: new framebuffer hash `fe0a77...`, no old x87-helper stall.

### Follow-Ups

- Keep the useful QEMU patch isolated to `target/i386/tcg/emit.c.inc`; the earlier `floatx80` trig experiment is not needed for this Ascendancy stall.
- Consider turning `DOS4GWTRIG` into a small upstream QEMU i386 TCG regression because it does not depend on Ascendancy or LainDOS internals beyond booting a COM program.
- The current Ascendancy probe likely stops on a later screen waiting for input; verify interactive gameplay under the `SAHF`-fixed QEMU separately if needed.

## 2026-05-27 Parallel QEMU Test Runner

### Symptoms

- After the shell input speedup, `make test` still spent about 30 seconds running largely independent QEMU tests serially.
- The tests could not be made parallel by Make alone because many scripts wrote shared artifacts like `build/boot.bin`, `build/shell.com`, and `build/testfile.dat`.

### Confirmed Facts

- Added `LAINDOS_TEST_BUILD_DIR` support through `scripts/testlib.py` and migrated default QEMU tests to use it for scratch artifacts.
- Added `scripts/run_tests.py` with `-j` parallelism and per-test build directories under a per-run root such as `build/tests/run-91601/08-test_shell`.
- Interactive monitor sockets now live under each test build directory, avoiding fixed `/tmp/laindos-*.sock` collisions for parallel/default tests.
- Successful runs now remove their per-run build root; failures preserve it for debugging. `--keep-build` keeps artifacts after success.
- `scripts/run_tests.py` has a 300-second default outer timeout per test and terminates the test process group on watchdog expiry.
- `make test` now runs `scripts/run_tests.py -j $(TEST_JOBS)` with default `TEST_JOBS=4`.
- `make test-serial` keeps a `-j 1` fallback path.
- Full parallel `make test` passed in 10.62 seconds wall time with `32/32` tests passing.
- Full serial fallback `make test-serial` passed in 29.47 seconds wall time with `32/32` tests passing.

### Tests Run

- `python3 -m py_compile scripts/test_*.py scripts/testlib.py scripts/run_test.py scripts/run_tests.py`
- `git diff --check`
- `python3 scripts/run_tests.py -j 3 scripts/test_boot.py scripts/test_shell.py scripts/test_envpath.py scripts/test_autoexec.py`
- `python3 scripts/run_tests.py -j 2 scripts/test_boot.py scripts/test_write.py`
- `python3 scripts/run_tests.py -j 1 --build-root build scripts/test_boot.py`
- `/usr/bin/time -p make test`
- `/usr/bin/time -p make test-serial`

## 2026-05-27 Shell Test Timing

### Symptoms

- After adding per-test timing, `scripts/test_shell.py` consistently took about 40 seconds while most QEMU tests completed under a second.
- The test was not actually waiting for the final QEMU timeout; the wall time matched hundreds of monitor `sendkey` calls sleeping 150 ms each.

### Confirmed Facts

- Replacing blind key-list playback with command-level injection plus prompt/marker waits preserves the same interactive coverage without flooding the BIOS keyboard buffer.
- QEMU monitor key hold was reduced to 10 ms and inter-key delay to 20 ms.
- `scripts/test_shell.py` passed repeated focused runs at about 6.6 seconds.
- Full `make test` passed in 30.88 seconds, down from about 66 seconds before the shell timing fix.

### Tests Run

- `python3 -m py_compile scripts/test_shell.py`
- `git diff --check`
- `python3 scripts/run_test.py python3 scripts/test_shell.py`
- `python3 scripts/run_test.py python3 scripts/test_shell.py && python3 scripts/run_test.py python3 scripts/test_shell.py`
- `/usr/bin/time -p make test`

## 2026-05-27 FAT Cluster Bounds Checks

### Symptoms

- FAT helpers trusted cluster numbers from directory entries and FAT chain entries.
- A corrupted FAT16 chain could point from a valid file cluster to an out-of-range cluster; the old read path tried to follow it and failed while reading `BADCHAIN.DAT`.
- A directory entry with an impossible first cluster could feed that value back into `fat_next`/`fat_set` during delete and risk writing outside the intended FAT range.

### Confirmed Facts

- `fat_next` now rejects input clusters below 2 or at/above `kmax_cluster` and returns EOC.
- `fat_next` also sanitizes out-of-range non-reserved FAT entry values to EOC before callers walk to them.
- `fat_set` now rejects invalid input clusters and sets the FAT I/O error flag instead of writing outside the FAT.
- `flush_fat` now reports the FAT I/O error flag for both FAT12 and FAT16.
- `cluster_lba` now maps invalid input clusters to a deliberately unaddressable CHS LBA so stale or corrupted first-cluster values fail safely at sector I/O instead of reading/writing leftover sectors.
- `read_sector` and `write_sector` now reject LBAs whose high word would overflow the first CHS division.
- The widened bounds checks required moving `SEC_BUF` to `0x08A0` and `ENV_SEG` to `0x08C0`; `ROOT_SEG` and the MCB arena remain unchanged.

### Tests Run

- `python3 -m py_compile scripts/test_badfat.py`
- `python3 scripts/test_badfat.py`
- `python3 scripts/test_fat16.py`
- `python3 scripts/test_fat16_large.py`
- `python3 scripts/test_fat16_seek.py`
- `python3 scripts/test_highdir.py`
- `python3 scripts/test_partitioned_fat16.py`
- `python3 scripts/test_dirmut.py`
- `python3 scripts/test_dirextfail.py`
- `make test`

## 2026-05-27 High-LBA FAT16 Directory Metadata

### Symptoms

- Partitioned FAT16 support exposed older directory-sector paths that kept only the low 16 bits of directory-entry LBAs.
- A focused `hd96m` image with `HIDIR` placed above sector `65535` failed before the fix: `HIGHDIR.COM` could not open `HIDIR\SEED.DAT`.

### Confirmed Facts

- File data I/O was already mostly high-LBA aware through `cluster_lba` and `kio_lba_hi`.
- Directory scans, free-slot search, directory initialization, empty-directory checks, and handle directory-entry flushing still used 16-bit directory sector fields.
- Widening directory-sector metadata and passing the high word through `kio_lba_hi` fixes high-subdirectory open/create/write/close/rename/mkdir/rmdir/delete/attribute updates.
- The widened kernel needed a small scratch-buffer layout adjustment: `SEC_BUF=0x0890`, `ENV_SEG=0x08B0`, with `ROOT_SEG` unchanged.

### Tests Run

- `python3 -m py_compile scripts/test_highdir.py`
- `python3 scripts/test_highdir.py`
- `python3 scripts/test_fat16_large.py`
- `python3 scripts/test_fat16_seek.py`
- `python3 scripts/test_partitioned_fat16.py`
- `python3 scripts/test_dirmut.py`
- `make test`

## 2026-05-27 Partitioned FAT16 HD Compatibility

### Symptoms

- LainDOS raw `hd32m`/`hd96m` FAT16 images boot in QEMU, but real MS-DOS did not read earlier LainDOS hard-disk images as normal DOS `C:` drives.
- The first partitioned test image booted LainDOS but real MS-DOS `DIR C:` over serial showed garbage directory entries.

### Confirmed Facts

- The original hard-disk image format was a raw FAT volume, not an MBR-partitioned disk.
- `boot16.asm` and the kernel initially treated FAT/root/data sector numbers as disk-absolute and did not add the BPB hidden-sector partition offset.
- A tiny MBR chainloader plus BPB hidden-sector addition lets LainDOS boot and run `MEMTEST.EXE` from a FAT16 partition starting at LBA 63.
- `fdisk build/fat16part.img` recognizes an active type-06 DOS partition starting at LBA 63.
- `fsck_msdos -n` accepts the extracted FAT16 partition slice from `build/fat16part.img`.
- Real MS-DOS 6.x, using a temporary floppy `AUTOEXEC.BAT` with `CTTY COM1`, mounted the partition as `C:` but listed garbage when the FAT boot sector OEM string and volume label were all zeros.
- After setting the FAT boot sector OEM string to `MSDOS5.0` and volume label to `NO NAME    `, real MS-DOS `DIR C:` listed `KERNEL.SYS` and `MEMTEST.EXE` correctly.

### Tests And Probes Run

- `python3 scripts/test_partitioned_fat16.py`
- `fdisk build/fat16part.img`
- `fsck_msdos -n build/fat16part_slice.img`
- Real MS-DOS floppy boot in QEMU with `CTTY COM1`, then `C:` and `DIR` against `build/fat16part.img`.

### Follow-Ups

- The current partitioned boot path still uses CHS `INT 13h`; keep images below the 1024-cylinder limit until an extended-read boot path exists.
- Older filesystem call sites still carry some directory sector LBAs in 16-bit variables; avoid high mutable directories until that follow-up audit is complete.

## 2026-05-26 Ascendancy QEMU x87 Stall

### Symptoms

- After the FAT16 read-path fix, user confirmed 86Box gets Ascendancy past the first Logic Factory screen quickly.
- QEMU still stays visually frozen on the first Logic Factory screen even after 180 seconds.
- `SETSOUND` sound set to `None` did not change the QEMU stall.

### Confirmed Facts

- The FAT16 seek/read fix was real: both `test_fat16_large.py` and the new `test_fat16_seek.py` pass, and 86Box startup speed improved.
- QEMU and 86Box both reach the same DOS trace pattern on `ASCEND00.COB`: after a successful 4 KB read at `0x1FB2F`, the game executes many `AH=42h AL=01h CX:DX=0` tell-style seeks returning `0x20B2F`.
- Under both QEMU and 86Box, that tell loop exits with a seek to `0x1FEEC` and `CLOSE H=0006`.
- Under 86Box, later DOS file activity continues immediately afterward (`ASCEND00/01/02.COB`, `ascend.cfg`, `resume.gam`, etc.).
- Under QEMU, a 180-second traced run produced no further DOS calls after that close, and the screenshot hash stayed at the stuck Logic Factory screen hash `8e5010bd947253405c00ac7f16d5cb0edf00901e17394d2e567a733b635c61b6`.
- QEMU BIOS tick dword at physical `0x46C` advances during the stall, so the BIOS timer is not globally dead.
- Adding `AH=44h AL=06h/07h` IOCTL status support did not change the QEMU stall.
- Switching QEMU from default VGA to `-vga cirrus` did not change the QEMU stall.
- A live QEMU monitor snapshot during the stall showed protected-mode execution inside DOS/4GW x87 math, first in an `fprem` loop and later in an `fcos`/`fsin` helper:
  - `fprem / wait / fnstsw / sahf / jp back`
  - then `fcos` and `fsin` calling into the same helper region.
- This means the DOS seek loop is only the last visible `INT 21h` activity; the real stall is in protected-mode floating-point code.
- LainDOS previously did no x87 initialization at all. Added `fninit` at kernel startup and before each child transfer (`exec_com`, `exec_exe`, `exec_com_dyn`, `exec_exe_dyn`).
- The `fninit` change did not clear the QEMU visual stall within 60 seconds, and a follow-up QEMU CPU sample still showed the DOS/4GW trigonometric helper active.
- For direct comparison, the isolated 86Box VM now uses `gfxcard = s3_trio64_pci`, and a traced `AUTOEXEC.BAT` image confirmed 86Box also hits the tell loop before moving on.
- A real DOS 6.22-style boot floppy in `build/DOS Boot Floppy.img` boots under QEMU and reaches `A:\>`.
- Booting that DOS floppy with `build/games_hd_all.img` attached directly does not expose a usable `C:` drive; DOS reports `Invalid drive specification`.
- Wrapping `build/games_hd_all.img` in a simple one-partition MBR image (`build/games_hd_all_dospart.img`) gives real DOS a `C:` prompt, but DOS reads the hard-disk root directory as garbage rather than the expected `ASCEND` tree, so it still cannot launch Ascendancy from that image.
- An alternate partition start at LBA 1 (`build/games_hd_all_dospart1.img`) behaved the same way, so the quick wrapper was not sufficient to make the LainDOS-built hard-disk image MS-DOS-compatible under QEMU.
- Using QEMU's FAT directory export as the hard disk (`file=fat:rw:<hostdir>`) with a copied DOS floppy worked much better: DOS sees a clean `C:` drive and the `ASCEND` directory.
- With `AUTOEXEC.BAT` set to `C:`, `CD \ASCEND`, `ASCEND`, real DOS in QEMU first exited because no mouse driver was loaded.
- After changing `AUTOEXEC.BAT` to load `MOUSE.COM` before running Ascendancy, real DOS in QEMU reached the same first Logic Factory screen as the LainDOS/QEMU path.
- The real-DOS/QEMU screenshots at 20s and 60s still matched the stuck Logic Factory screen hash, so the QEMU-specific stall reproduces even outside LainDOS.
- QEMU 11.0.0 on this host exposes only the `tcg` accelerator for x86 guests; there is no quick `hvf`/`kvm` bypass for TCG x87.
- A small CPU/FPU sweep under the real-DOS reproduction (`-cpu 486`, `-cpu pentium2`, `-cpu pentium,-fpu`, `-cpu qemu64`) did not change the 20-second Logic Factory screen hash.
- Live QEMU monitor samples during the real-DOS reproduction still landed inside the DOS/4GW x87 helper. One sample showed the tail of the `fprem` loop, and a later sample showed the `fcos`/`fsin` wrapper calling back into the same helper.
- The FPU state was not obviously inert: the sampled FPU status word changed between two closely spaced snapshots (`FSW=3820` then `FSW=3020`) while execution remained in the same helper area.
- A 12-sample QEMU time series under the real-DOS reproduction stayed entirely inside that helper region (`0x001d695a`..`0x001d6994`) and produced 9 unique `(EIP, FSW, FPR6, FPR7)` tuples.
- In those samples, one x87 value stayed near `0.7390851332` while the other alternated between that value and about `2π`, suggesting the helper is cycling between a tiny set of x87 states rather than making visible forward progress toward the next screen.
- A disposable 86Box VM copy was then configured with `cpu_use_dynarec = 0` and `fpu_softfloat = 1` to push 86Box closer to a software-FPU path.
- Even in that 86Box softfloat configuration, the traced Ascendancy run still got through the same `ASCEND00.COB` tell-loop and continued into later file activity (`ASCEND00/01/02.COB`, `DIG.INI`, `SB16.DIG`, `RESUME.GAM`, etc.) within the capture window.
- A same-image LainDOS trace comparison confirmed the first material divergence is not file I/O. QEMU and 86Box share the same startup/resource sequence through the `ASCEND00.COB` tell-loop and close; 86Box then opens more resources, while QEMU stays in protected-mode x87 code with no more DOS calls.
- A 180-second QEMU monitor snapshot after the last DOS call showed `EIP=001c6994`, `FCW=127f`, `FSW=3820`, and execution around the Ascendancy/DOS4GW range-reduction helper (`fldt 2pi`, `fxch`, `fprem`, `fnstsw`, `sahf`, `jp`, `fstp st1`, `ret`). `FSW=3820` has C2 clear at that sample, so the observed state is not an infinite single `fprem` instruction loop.
- A temporary standalone x87 diagnostic (`build/fputest.asm` / `build/fputest.img`) now reproduces a QEMU-vs-Bochs difference outside Ascendancy. With the same LainDOS boot image, QEMU and Bochs agree on `2pi` and a simple `fprem` result, but QEMU's `fsin`/`fcos` outputs have double-precision-looking low bits while Bochs preserves fuller 80-bit results.
- The same diagnostic shows a stronger range-reduction divergence: for a double argument just above the x87 trig range threshold (`0x43E0000000000001`, i.e. `2^63 + 1 ULP at that magnitude, or 2048`), the Ascendancy-style wrapper loops in QEMU until the diagnostic aborts (`FAIL: FPUTEST C PREM=0001 WRAP=0041 SW=3C00 VAL=403E8000000000000800`; C2 set at abort), while Bochs completes `COS_LARGE`/`SIN_LARGE` with `WRAP=0002` and prints `PASS: FPUTEST`.
- Upstream QEMU issue `#83` is directly relevant: `QEMU x87 emulation of trig and other complex ops is only at 64-bit precision, not 80-bit` (`https://gitlab.com/qemu-project/qemu/-/issues/83`). The Launchpad source discussion for that issue, especially comments #13 and #15, says QEMU still implements `FPTAN`, `FSINCOS`, `FSIN`, and `FCOS` by converting `floatx80` to host `double` and using host C math routines, while `FPREM`, `FPREM1`, `FPATAN`, `FYL2X`, `FYL2XP1`, and `F2XM1` were reworked for proper 80-bit operations in QEMU 5.1-era commits.
- Related but less directly relevant upstream QEMU issue `#984` reports an i386 x87 `fldl`/precision-control conversion bug in QEMU 6.1..7.0-rc4 (`https://gitlab.com/qemu-project/qemu/-/issues/984`). It is another TCG x87 precision issue, but not the Ascendancy trig/range-reduction behavior.

### Tests And Probes Run

- `python3 scripts/test_ioctlstat.py`
- `python3 scripts/test_fat16_large.py`
- `python3 scripts/test_fat16_seek.py`
- `make test` after adding the FAT16 seek regression and IOCTL status test
- QEMU screenshot smokes at 20s, 60s, 180s on default VGA and 60s on `-vga cirrus`
- QEMU monitor probes:
  - `xp /1dw 0x46c` during stall
  - `info registers`
  - `x /12i $eip`
- 86Box traced `AUTOEXEC.BAT` run with S3 Trio PCI
- QEMU `-cpu pentium` 60s smoke
- QEMU real-DOS CPU/FPU sweep: `-cpu 486`, `-cpu pentium2`, `-cpu pentium,-fpu`, `-cpu qemu64`
- QEMU real-DOS live FPU/CPU monitor sampling with `info registers` and `x /16i $eip`
- QEMU real-DOS x87 helper time series (12 monitor samples over ~12 seconds)
- 86Box softfloat/dynarec-off comparison run using a copied VM profile
- Same-image LainDOS trace comparison:
  - `build/asc_tracecmp.img` under QEMU for 70s and 180s, serial logs `build/asc_tracecmp_qemu_serial.log` and `build/asc_tracecmp_qemu_180s_serial.log`
  - copied to `build/86box-compare/games_hd_all.img` and run under 86Box, serial log `build/asc_tracecmp_86box_serial.log`
  - QEMU monitor snapshot saved as `build/asc_tracecmp_qemu_180s_monitor.log`
- Temporary x87 diagnostic:
  - `nasm -f bin build/fputest.asm -o build/fputest.com`
  - `nasm -DBOOT_FILE='"FPUTEST COM"' -f bin src/kernel.asm -o build/fputest_kernel.bin`
  - `python3 scripts/mkimage.py --format=1440k build/fputest_boot.bin build/fputest_kernel.bin build/fputest.img build/fputest.com`
  - QEMU output saved as `build/fputest_qemu_serial.log`
  - Bochs output saved as `build/fputest_bochs_serial.log`
- QEMU issue search:
  - GitLab API searches for `x87`, `fprem`, `fsin`, `fcos`, `fptan`, `fpu_helper`, `floatx80_to_double`, `MAXTAN`, `Ascendancy`, `DOS4GW`, and `DOS/4GW`
  - direct fetches of `https://gitlab.com/qemu-project/qemu/-/issues/83`, `https://gitlab.com/qemu-project/qemu/-/issues/984`, and Launchpad source `https://bugs.launchpad.net/qemu/+bug/645662`
- Real DOS probes under QEMU:
  - boot `build/DOS Boot Floppy.img` with `build/games_hd_all.img`
  - boot a copied floppy with `AUTOEXEC.BAT` replaced to run `C:`, `DIR`, and `ASCEND`
  - build and test `build/games_hd_all_dospart.img` and `build/games_hd_all_dospart1.img`
  - boot a copied floppy that loads `MOUSE.COM` and runs `ASCEND` against `file=fat:rw:build/realdos_asc`

### Follow-Ups

- The remaining likely cause is QEMU-specific x87 behavior in trig/range-reduction, not LainDOS DOS/FAT behavior.
- The standalone `FPUTEST` result is strong enough to preserve as a minimal emulator reproducer if we decide to file/report a QEMU issue; keep it out of `make test` because it intentionally exposes a QEMU failure.
- High-value next probes are extracting the exact Ascendancy wrapper arguments from QEMU/Bochs around the stall and reducing `FPUTEST` to the smallest possible QEMU bug reproducer.
- The real-DOS/QEMU reproduction via QEMU FAT export makes a fully DOS-compatible FAT16 disk image lower priority for this Ascendancy stall: the bug reproduces under real DOS already.
- The additional CPU-model sweep did not shake the stall loose, so the most promising remaining branch is direct QEMU x87 diagnosis (GDB/monitor/Bochs), not more image-layout work.
- 86Box's softfloat run and Bochs's standalone `FPUTEST` pass both point to a QEMU-specific x87 helper issue rather than a generic emulator-softfloat limitation.

## 2026-05-26 FAT16 Subdirectory Truncate Corruption

### Symptoms

- User reported Ascendancy `SETSOUND.EXE` appeared to write forever instead of saving configuration.
- Expanded `scripts/test_fat16_large.py` reproduced a generic large FAT16 write issue as `FAIL: FAT16BIG REOPEN` after creating, verifying, truncating, and reopening `\CFGDIR\SET.DAT`.
- After the failure, `CFGDIR` sector LBA 281 started with the same bytes as FAT sector LBA 33, and the new `SET     DAT` entry appeared inside that copied FAT-sector data.

### Confirmed Facts

- In the 96 MiB image, `CFGDIR` is intentionally low at LBA 281, while LBA 33 is the FAT16 sector covering high clusters used by the large-file regression.
- The corruption happened on `INT 21h AH=3Ch` when truncating an existing file in a subdirectory.
- For FAT16, `fat_free_chain`/`fat_set` use `SEC_BUF` for FAT sector I/O. The create/truncate path kept the existing subdirectory entry in `SEC_BUF`, freed the old chain, then cleared and flushed what it thought was still the directory sector. By then `SEC_BUF` contained the FAT sector.
- Root-directory truncation did not hit this because root entries live in `ROOT_SEG`, and FAT12 did not hit it because FAT updates use `FAT_SEG`.

### Fix

- `AH=3Ch` now saves the target directory-entry LBA when the entry is found/allocated.
- When truncating an existing subdirectory file, it reloads that directory sector into `SEC_BUF` after freeing/flushing the old FAT chain and before clearing/reusing the entry.
- The handle's directory LBA and the create-time directory flush now use the saved create-entry LBA.

### Tests And Probes Run

- `python3 scripts/test_fat16_large.py` failed before the fix with `FAIL: FAT16BIG REOPEN` and passes after the fix.
- Focused checks passed: `python3 scripts/test_fat16.py`, `python3 scripts/test_write.py`.
- `make test` passes with the expanded large FAT16 regression included.
- `python3 -m py_compile scripts/mkimage.py scripts/build_games_hd_all.py scripts/test_fat16.py scripts/test_fat16_large.py scripts/test_mi2_save.py` passes.
- `python3 scripts/build_games_hd_all.py` passes.
- `python3 scripts/test_mi2_save.py` passes on the rebuilt all-games image.
- SETSOUND smoke with QEMU `-device sb16`: the save/Done flow returns to `C:\ASCEND>` instead of hanging in the save path. Automatic/full SB16 detection was not proven; one attempted automatic path stopped at the Miles driver-selection screen.
- `code-reviewer-zai` found no blocking issues. Follow-ups incorporated: reload `DI` from the saved directory-entry offset before clearing the entry, remove a redundant `cf_entry_off` save, and add root-directory truncate coverage to `FATBIG.COM`.

### Follow-Ups

- Add or keep higher-level Ascendancy sound-config automation if we need to prove a fully configured SB16 `DIG.INI` save, not just the generic truncate/save path.

## 2026-05-26 Ascendancy Local CD COB

### Symptoms

- Ascendancy reached its DOS/4GW startup and copyright banner but exited with `Please place the Ascendancy CD in your CDROM drive.`
- The installed `COB.CFG` pointed the third data archive at `D:\DATA\ASCEND02.COB` while the all-games image intentionally excluded the nested CD-image directory.

### Confirmed Facts

- `build/ascendancy/ascendy/cd/ascendancy.img` is a raw 2352-byte-sector Mode 1 CD image; ISO data starts at byte offset 16 of each sector.
- The CD image contains `DATA/ASCEND02.COB`, size 60,787,718 bytes.
- Copying only that file plus the installed `ascendy/` tree makes the all-games payload about 89 MiB, so the all-games image now uses a 96 MiB FAT16 format.
- Reading and writing files past sector 65535 required widening kernel sector I/O to use a high LBA word and fixing BPB total-sector handling for the FAT16 large-total field.
- Runtime saves on the larger image initially stalled with MI2 reporting `The game was NOT saved (disk full?)`; the root cause was the FAT allocator scanning from cluster 2 for every allocation. A next-fit allocation hint fixed multi-cluster writes when free space starts high in the image.
- `mise run-games-hd-all` and `mise run-monkey-full` now add `-device sb16` to QEMU.

### Tests And Probes Run

- Added `scripts/test_fat16_large.py` and `tests/programs/fatbig.asm`; before the 32-bit sector fix it failed with `FAIL: FAT16BIG DATA`, and before the allocator hint it failed with `FAIL: FAT16BIG WRITE`.
- `python3 scripts/test_fat16_large.py` passes after reading a marker beyond the 32 MiB boundary and creating/reading a new high-cluster file.
- `python3 scripts/build_games_hd_all.py` now creates a 100,638,720-byte image containing `C:\ASCEND\ASCEND02.COB` and a rewritten `COB.CFG` with `ASCEND02.COB` as the third line.
- Ascendancy smoke with QEMU `-device sb16`: `C:\ASCEND>ascend` reaches the DOS/4GW and Ascendancy banners, does not print the missing-CD prompt, and shows no `EXC ` marker during the smoke window.
- `python3 scripts/test_mi2_save.py` passes on the enlarged all-games image after the allocator hint.
- `make test` passes with the new large FAT16 regression included.

### Follow-Ups

- Directory-entry LBAs are still stored in 16-bit fields. The generated all-games image keeps directories low, so current Ascendancy/MI2 flows are covered, but fully general high-directory mutation would require widening those fields too.
- The 96 MiB format still uses CHS INT 13h and stays well below the 1024-cylinder limit with 16 heads and 63 sectors per track. Larger future images should move to INT 13h extensions or fully audited 32-bit CHS paths.

## 2026-05-26 Ascendancy DOS/4GW Startup

### Symptoms

- After FAT16 support, `C:\ASCEND>setsound` and `C:\ASCEND>ascend` still did not start successfully.
- With VGA/VNC enabled, both initially reached `EXC 06 at 11CE:F085` with bytes `D9 8A 00 00 ...`; screenshots still showed the shell prompt.
- With `-nographic`, `setsound` sometimes returned to the prompt without the visible DOS/4GW path, so VGA-enabled runs were used for the real start test.

### Confirmed Facts

- The shared fault segment `11CE` matches the DOS4GW.EXE MZ entry CS when loaded as an `INT 21h AX=4B03h` overlay at the stub-requested load segment, not a SETSOUND/ASCEND protected-mode payload address.
- The generic overlay loader used only the low 16 bits of the directory file size. For `DOS4GW.EXE` the full file is 265,420 bytes, so the low word is `0x0CCC`; the loader copied only about 2.7 KiB after the MZ header instead of the MZ-declared 62 KiB real-mode image.
- A focused overlay regression now appends data after the MZ image so the full directory length low word is smaller than the MZ image, and checks a tail marker near the MZ image end. It failed before the overlay loader fix with `FAIL: OVERLAY TAIL`.
- `INT 21h AX=4B03h` now uses MZ page-count/last-page image size for EXE overlays and rejects overlay images that exceed the current 16-bit copy length.
- After the overlay fix, DOS/4GW progressed to ordinary DOS calls `AH=38h` country info and `AH=33h` Ctrl-Break state. LainDOS now implements those generically with US country defaults, break get/set, boot-drive query, and true-version query.
- `SHELL.COM` now switches to an internal resident stack and shrinks its own PSP block at startup. This is generic command-processor memory behavior and avoids keeping its initial high COM allocation slack resident during child execution.
- Kernel growth required moving `SEC_BUF` and `ENV_SEG` upward within low memory; layout guards now also ensure `ENV_SEG` remains below `ROOT_SEG`.

### Tests And Probes Run

- DOS trace before the overlay fix showed `setsound` opening `DOS4GW.EXE`, reading 28 MZ header bytes, then performing memory probes before the `EXC 06`; no later DOS file reads occurred because DOS4GW had been underloaded as an overlay.
- `python3 scripts/test_overlay.py` fails before the overlay-size fix with `FAIL: OVERLAY TAIL` and passes after the fix.
- `python3 scripts/test_dosstruct.py` fails before `AH=38h`/`AH=33h` support with `INT 21h AH=38` and passes after the API implementation.
- VGA smoke after the fixes: `C:\ASCEND>setsound` reaches the Miles Sound Configuration Utility UI.
- VGA smoke after the fixes: `C:\ASCEND>ascend` reaches the DOS/4GW banner, prints the Ascendancy copyright banner, then exits cleanly with `Please place the Ascendancy CD in your CDROM drive.`
- Focused checks passed: `python3 scripts/test_overlay.py`, `python3 scripts/test_dosstruct.py`, and `python3 scripts/test_shell.py`.
- Full `make test` passes.
- Standalone `python3 scripts/test_mi2_save.py` passes after the shell/memory and overlay changes.
- `python3 -m py_compile scripts/build_games_hd_all.py scripts/test_mi2_save.py scripts/test_overlay.py scripts/test_dosstruct.py` passes.
- `git diff --check` passes.

### Follow-Ups

- Full Ascendancy gameplay still needs CD-ROM/MSCDEX or inclusion/mounting of the CD assets; the current progress reaches the expected missing-CD prompt.
- DOS overlay loading still uses a 16-bit remaining-byte counter and rejects MZ overlay images above 64 KiB; larger overlays need a wider copy path if encountered.

## 2026-05-26 FAT16 HD Image Support

### Symptoms

- Ascendancy inclusion pushed the all-games image against awkward FAT12 hard-disk limits. The prior `hd32m` FAT12 workaround needed large clusters and a boot-time FAT/root memory layout that could not scale cleanly.
- A combined FAT12/FAT16 boot sector exceeded 512 bytes, so the hard-disk FAT16 path needed a separate boot sector.
- After initial FAT16 work, `make test` failed in `scripts/test_boot.py` after `scripts/test_autoexec.py`; serial output reached only `NoK`.
- Standalone `scripts/test_mi2_save.py` initially failed on the FAT16 games image without creating `C:\MI2\SAVEGAME.002`.

### Confirmed Facts

- `scripts/mkimage.py` now supports `fat_bits` per format and makes `hd32m` a FAT16 image with 65,520 sectors, 8 sectors per cluster, 512 root entries, and 32 sectors per FAT.
- Added `src/boot16.asm` for FAT16 hard-disk boots while keeping `src/boot.asm` as the FAT12 floppy boot path.
- `src/kernel.asm` detects FAT16 from the BPB fs type string, uses format-specific EOC/reserved values and root-entry limits, and reads/writes FAT16 entries through sector-sized FAT I/O rather than assuming the full FAT fits in `FAT_SEG`.
- The `NoK` failure was build artifact contamination: the focused FAT16 test assembled `src/boot16.asm` to `build/boot.bin`, so later FAT12 image builds reused a FAT16 boot sector. `scripts/test_fat16.py` now writes `build/boot16.bin` instead.
- The MI2 save failure was automation, not yet confirmed as filesystem data loss: screenshots showed the mouse stayed on the F5 menu and never clicked `Save`. The save script now moves the mouse in bounded relative steps and reads FAT16 cluster chains when checking the image.
- `scripts/build_games_hd_all.py` uses `src/boot16.asm` and the FAT16 `hd32m` format for the all-games image.
- Code review found that a 512-entry FAT16 root at the old `ROOT_SEG=0x0180` would overlap the relocated kernel from entry 224 onward. `ROOT_SEG` is now `0x0920`, below `MCB_START` and above the kernel stack top, and assembly-time guards cover the root buffer placement.
- Review follow-ups also guard `flush_fat` from writing stale `FAT_SEG` data on FAT16, preserve FAT16 write-through I/O failures until the next `flush_fat`, remove a dead FAT12-only helper from `mkimage.py`, make the raw `boot16.asm` BPB total-sector fields spec-compliant, stamp FAT12/FAT16 BPB fs type strings in generated images, and make the MI2 image reader stop at FAT16 reserved cluster values.

### Tests And Probes Run

- `python3 scripts/test_fat16.py` passes and boots a FAT16 image through `MEMTEST.EXE`; the image puts `MEMTEST.EXE` beyond root entry 224 to cover the old root/kernel overlap boundary.
- `make -B build/boot.bin && make build/disk.img && python3 scripts/test_boot.py` passes after isolating the FAT16 boot artifact.
- `make test` passes with `scripts/test_fat16.py` included after the review fixes.
- Standalone `python3 scripts/test_mi2_save.py` passes and creates `SAVEGAME.002` on the FAT16 all-games image after the mouse automation and FAT16 image-reader fixes.
- `python3 scripts/build_games_hd_all.py` rebuilds `build/games_hd_all.img` as FAT16, and a QEMU hard-disk boot smoke reaches `LainDOS Shell` at `C:\>`.
- Image inspection confirmed `fs=b'FAT16   '`, `spc=8`, `fat_sz=32`, `root_cnt=512`, and an `ASCEND` root directory entry.
- `python3 -m py_compile scripts/mkimage.py scripts/test_fat16.py scripts/test_mi2_save.py scripts/build_games_hd_all.py` passes.
- `git diff --check` passes.

### Follow-Ups

- FAT16 coverage currently boots past the high-root-entry boundary and writes through the MI2 save path, but focused FAT16 root-directory write regressions would be useful if FAT16 becomes a heavier development target.
- Ascendancy still reaches the existing DOS/4GW `EXC 06` compatibility boundary; FAT16 only resolves the image sizing and FAT layout constraints.

## 2026-05-26 Ascendancy Games Image

### Symptoms

- The user added `vendor/Ascendancy_1995.zip` and asked to include it in the all-games hard-disk image.
- The archive is much larger than the existing `hd20m` image path: about 110 MB uncompressed, mostly a nested `ascendy/cd/ascendancy.img` CD image.

### Confirmed Facts

- The installed Ascendancy files under `ascendy/`, excluding the nested `cd/` image directory, are about 14 MB.
- The existing all-games payload plus those installed files fits in a FAT12-safe hard-disk image below the current 16-bit sector limit, using 16 sectors per cluster and 12 FAT sectors.
- Added an `hd32m` mkimage format and switched `scripts/build_games_hd_all.py` to use it.
- `scripts/build_games_hd_all.py` now extracts `vendor/Ascendancy_1995.zip` and places the installed `ascendy/` files in an `ASCEND` directory on `build/games_hd_all.img`; nested `ascendy/cd/` CD image files are intentionally not included.
- The first successful `hd32m` image still used a 12-sector FAT, which overlapped the boot/kernel memory map: boot loads the FAT at `FAT_SEG=0x0060` and the root directory at `ROOT_SEG=0x0180`, so FAT data beyond 9 sectors is overwritten by the root directory. That corrupted FAT entries for late Ascendancy files like `DOS4GW.EXE` and caused EXEC I/O failure.
- `hd32m` now keeps a 9-sector FAT and uses 22 sectors per cluster, staying within the existing FAT/root memory layout while leaving enough data capacity for the installed Ascendancy files.
- Ascendancy's DOS/4GW-bound EXEs have an MZ header image size of about 10 KiB but carry a much larger protected-mode payload appended to the DOS image. LainDOS was using the full directory file length for EXE loading, so `ASCEND.EXE` was treated as a 587 KiB conventional-memory image and could not load from the shell. The EXE loader now uses the MZ page-count/last-page fields for the conventional image size and leaves appended payload bytes on disk for the extender to read.
- The DOS/4GW stub also allocates 1-paragraph probe blocks and tries to resize them to maximum size. LainDOS's MI2 workaround placed all tiny default allocations high, so those 1-paragraph probes could not see the large following free block. Default 1-paragraph allocations now use normal first-fit; 2..32 paragraph default allocations still use high placement for the MI2 overlay pattern.
- Added minimal `INT 21h AH=52h` list-of-lists support with `[ES:BX-2]` pointing at `MCB_START`, and minimal `AH=29h` FCB filename parsing. DOS/4GW reaches further with these APIs than with the generic unhandled-call failure.
- Code review found a drive-letter parsing bug in the initial `AH=29h` parser; drive-qualified FCB inputs now set the FCB drive byte during the scan.

### Tests And Probes Run

- The first `hd32m` size attempt was too tight once actual cluster allocation was applied.
- `python3 scripts/build_games_hd_all.py` rebuilt `build/games_hd_all.img` successfully at 33,488,896 bytes.
- Image directory inspection confirmed root `FREE.COM`, root `ASCEND`, and `ASCEND\ASCEND.EXE`, `ASCEND\ASCEND01.COB`, and `ASCEND\DOS4GW.EXE` entries.
- `python3 -m py_compile scripts/build_games_hd_all.py scripts/mkimage.py` passes.
- `make test` passes.
- `git diff --check` passes.
- A QEMU hard-disk boot smoke of `build/games_hd_all.img` reaches `LainDOS Shell` at `C:\>` with no `FAIL:`, `EXC `, or `INT 21h AH=` markers.
- Reproduced the broken launch before the cluster-size fix: `C:\ASCEND>setsound` and `dos4gw.exe` printed `Bad command or file name`; a diagnostic EXEC probe against the full image returned `AX=0001`, while the same file layout without earlier game payloads worked, confirming late-file FAT corruption rather than a DOS4GW compatibility failure.
- After the FAT fix, `setsound.exe` found `DOS4GW.EXE` but failed with `Not enough memory`, exposing the 1-paragraph allocation placement issue.
- After the allocation and MZ-size fixes, both `setsound.exe` and `ascend.exe` start DOS/4GW rather than failing at shell/EXEC time.
- Current Ascendancy blocker: `setsound.exe` reaches DOS/4GW startup and then traps with `EXC 06 at FF53:093B`; `ascend.exe` traps with `EXC 06 at 0000:0003`. This is beyond file placement/EXEC and is likely the next protected-mode/DOS-extender compatibility boundary.
- Added `tests/programs/dosstruct.asm` and `scripts/test_dosstruct.py` to cover `AH=52h` first-MCB exposure and `AH=29h` drive/name parsing.
- Final verification for this round: `python3 scripts/build_games_hd_all.py`, `python3 scripts/test_dosstruct.py`, `python3 -m py_compile scripts/build_games_hd_all.py scripts/mkimage.py scripts/test_dosstruct.py`, `make test`, standalone `python3 scripts/test_mi2_save.py`, and `git diff --check` pass.

### Follow-Ups

- Full Ascendancy CD-image inclusion would require larger-disk support beyond the current 16-bit/FAT12 image path, and likely CD-ROM/MSCDEX-compatible behavior if the game requires the CD assets.
- Continue DOS/4GW bring-up from the `EXC 06` traps if Ascendancy becomes a target; likely areas are protected-mode transition assumptions, DOS extender memory interfaces, and remaining DOS compatibility APIs.

## 2026-05-25 FREE.COM Memory Report

### Symptoms

- The shell `MEM` built-in only probes `INT 21h AH=48h BX=FFFFh` and prints the largest free block in paragraphs.
- The user wanted a more useful DOS-style memory tool showing where blocks are loaded and overall free memory.

### Confirmed Facts

- Added `FREE.COM`, a small external utility that walks LainDOS's MCB chain from `MCB_START` and prints each block's MCB segment, status, owner PSP, data segment, size in paragraphs, and size in KB.
- The report marks free blocks as `FREE`, the utility's own PSP-owned block as `SELF`, and other allocated blocks as `USED`.
- The summary prints total managed memory, used memory, total free memory, and largest free block.
- The first version corrupted the status string pointer while printing row spacing; preserving the status pointer fixed the garbled row output.
- `FREE.COM` is included in the default build image and is exercised both as a direct boot target and through `SHELL.COM` command execution.
- Code review found no utility correctness bugs; follow-up hardening added MCB chain bounds checks, centralized MCB constants in `memory.inc`, checked `Invalid MCB chain` as a shell-test failure marker, and validated focused-test summary totals with paragraph-to-KB truncation tolerance.

### Tests And Probes Run

- `python3 scripts/test_free.py` passes.
- `python3 scripts/test_shell.py` passes with `FREE.COM` in the shell image.
- `python3 -m py_compile scripts/test_free.py scripts/test_shell.py` passes.
- `make test` passes with `scripts/test_free.py` included.
- `git diff --check` passes.
- After review follow-ups, `python3 scripts/test_free.py`, `python3 scripts/test_shell.py`, `python3 -m py_compile scripts/test_free.py scripts/test_shell.py`, `make test`, and `git diff --check` pass.
- An intermediate focused-test run caught a Python helper shadowing bug in `scripts/test_free.py`; renaming the local summary variable fixed it before the final full run.

### Follow-Ups

- MCB owner names are not yet available because LainDOS does not populate DOS-style MCB name fields.
- Environment blocks are still outside the MCB arena until the existing environment-MCB issue is handled, so they do not appear as separate report rows.

## 2026-05-25 Drive Selection Compatibility

### Symptoms

- `INT 21h AH=0Eh` selected disk returned a drive count but ignored caller `DL`, so `AH=19h` never reflected the requested default drive.
- `INT 21h AH=47h` get current directory ignored `DL` and succeeded for unsupported drive numbers.

### Confirmed Facts

- New hard-disk regression `DRIVE.COM` starts on `C:`, verifies `AH=47h` succeeds for default and `C:`, rejects invalid `D:`, selects `A:`, verifies `AH=19h` reports `A:`, verifies `AH=36h` still accepts `C:` while `A:` is selected, then selects `C:` again and rejects invalid select `D:` without changing the current drive.
- Before the fix, `python3 scripts/test_drive.py` failed with `FAIL: DRIVE CURDIR INVALID`.
- LainDOS now stores a stable logical drive count separately from the selected drive number. Floppy boots expose one logical drive; hard-disk boots expose `A:` through `C:` while still mapping all supported letters to the boot image.
- `AH=47h` now returns invalid-drive error `AX=000F` with carry set when `DL` names a drive beyond the logical drive count.
- `AH=36h` now validates requested 1-based drives against the stable logical drive count instead of the currently selected drive number.
- Review found no correctness bugs and suggested adding floppy-path and extra disk-free coverage; `DRIVE.COM` now branches on initial boot drive and tests both hard-disk and floppy images.

### Tests And Probes Run

- `python3 scripts/test_drive.py` passes after the fix for both hard-disk and floppy images.
- `python3 -m py_compile scripts/test_drive.py` passes.
- `make test` passes with the expanded `scripts/test_drive.py` included.
- `git diff --check` passes.

### Follow-Ups

- Broader per-drive current directories and actual multi-drive media remain out of scope; all supported logical drive letters still use the boot image.

## 2026-05-25 Register Preservation Follow-Ups

### Symptoms

- Advisor review found three more concrete register-preservation hazards after the Simon `AH=4Ah` fix: IOCTL get-device-info, file timestamp set, and mouse setter calls.
- A test-first `REGPRES.COM` update failed before the kernel fixes with `FAIL: REGPRES MOUSE SET REGS`, confirming at least one live clobber.

### Confirmed Facts

- `INT 33h AX=0004h`, `AX=0007h`, and `AX=0008h` called `mouse_clamp_position`, which used `AX` as scratch and returned with `AX` holding the clamped Y coordinate.
- `INT 21h AH=44h AL=00h` used `CX` for `HANDLE_SIZE` and `mul cx` while computing handle offsets. The invalid-handle path also let `mul` clobber `DX` before returning an error.
- `INT 21h AH=57h AL=01h` copied input `CX/DX` to temporary storage, then used `CX` for `HANDLE_SIZE` and `mul cx`; set-time success and error paths returned with caller `CX/DX` clobbered.
- Fixes preserve `AX` around mouse clamping, preserve `CX/DX` around IOCTL handle offset computation, and keep saved `CX/DX` on the file-time stack frame while still returning timestamp outputs for `AH=57h AL=00h`.
- Review found no correctness bugs and suggested two extra coverage checks; `REGPRES.COM` now also covers the IOCTL early invalid-handle path and `AH=57h AL=00h` get-time outputs after a set-time call.

### Tests And Probes Run

- Before the kernel fixes, `python3 scripts/test_regpres.py` failed with `FAIL: REGPRES MOUSE SET REGS`.
- After the fixes and review follow-up coverage, `python3 scripts/test_regpres.py` passes.
- `make test` passes after the review follow-up coverage.
- `git diff --check` passes.
- A focused direct QEMU boot of `MOUSE.EXE` passes with `PASS: MOUSE` and `Program exited, code=00`.

### Follow-Ups

- Request code review before committing or archiving the three focused register-preservation issues.

## 2026-05-25 Simon RUNVGA Resize Register Preservation

### Symptoms

- `C:\SIMON>RUNVGA GDEMO /3` opened and read `GDEMO`, then stopped making DOS calls and appeared stuck in the Watcom heap/runtime path.
- A CPU sample from the old failure had `DS=F000` while executing in the RUNVGA heap allocator path, suggesting corrupted caller state rather than a bad file read.
- The first post-fix screenshot artifact used a misleading PNG path; QEMU `screendump` was recaptured as native PPM and converted to a real PNG.

### Confirmed Facts

- Temporary INT 21h DS tracing did not find a DOS return with `DS=F000`; the bad segment came from RUNVGA's own far heap list after prior state corruption.
- `INT 21h AH=4Ah` resize used `DL` for the MCB signature and modified `CX`, so successful resize calls did not preserve caller `CX/DX`.
- `INT 21h AH=35h` get-vector returned the vector in `ES:BX` but also clobbered `SI` while reading the IVT.
- `REGPRES.COM` now covers register preservation for `AH=2Ch`, `AH=35h`, `AH=0Bh`, successful `AH=4Ah` shrink/grow paths, and the `AH=4Ah` failure path. It also sanity-checks that `AH=35h` returns a nonzero `ES:BX` vector.
- Rebuilt `build/games_hd_all.img`, booted QEMU/VNC, ran `CD SIMON` and `RUNVGA GDEMO /3`, and captured `build/simon_resizefix.ppm` plus a converted real `build/simon_resizefix.png`. The PNG shows Simon in-game with the verb UI visible.
- The post-capture CPU sample is in BIOS code with `DS=SS=416E`, not the earlier bad `DS=F000` heap-loop state.

### Tests And Probes Run

- `python3 scripts/build_games_hd_all.py` rebuilt the all-games image.
- Focused QEMU Simon smoke captured `build/simon_resizefix.png` and `build/simon_resizefix_serial.log`; serial output shows launch through `C:\SIMON>runvga gdemo /3` with no `EXC` or DOS failure markers.
- `python3 scripts/test_regpres.py` passes.
- `python3 scripts/test_shell.py` passes.
- `make test` passes.
- `git diff --check` passes.
- `python3 scripts/test_monkey_full.py` passes with framebuffer activity.
- `python3 scripts/test_mi2_save.py` passes and creates `SAVEGAME.002`.
- Code review found no kernel defects, but identified the missing `AH=4Ah` error-path coverage and `AH=35h` output sanity check; both were added and `python3 scripts/test_regpres.py`, `make test`, and `git diff --check` still pass afterward.

### Follow-Ups

- Get code review before committing the INT 21h register-preservation changes.
- Keep the recreated Simon screenshot as PPM plus converted PNG if more visual inspection is needed; QEMU's native screendump format is PPM.

## 2026-05-25 HD Games DIR Listing

### Symptoms

- The all-games HD image appeared to contain only kernel files when viewed through the shell runner.
- Rebuilding `build/games_hd_all.img` still produced a FAT image with root directories for `M1DEMO`, `MONKEY`, `MI2DEMO`, `MI2`, and `SIMON`, so the builder was adding game files correctly.

### Confirmed Facts

- A direct FAT directory scan showed `KERNEL.SYS`, `SHELL.COM`, and all game directories with populated subdirectories.
- Running `DIR` inside LainDOS on `build/games_hd_all.img` initially printed only `KERNEL.SYS` and `SHELL.COM`.
- The shell `DIR` command used `FindFirst` with `CX=0`, which excludes directory entries after the FindFirst attribute-filtering fix.
- Updating shell `DIR` to call `FindFirst` with `CX=0x10` includes directory entries again.

### Tests And Probes Run

- `python3 scripts/build_games_hd_all.py` rebuilt the all-games image.
- A QEMU shell probe of `DIR` on `build/games_hd_all.img` now shows `M1DEMO`, `MONKEY`, `MI2DEMO`, `MI2`, and `SIMON`.
- `scripts/test_shell.py` now adds a `DIRONLY` subdirectory and asserts it appears in shell `DIR` output.

## 2026-05-25 Architecture Review Follow-Up

### Symptoms

- A broad review after Phase 17 found a high-confidence MCB split bug in `alloc_mem_direct_high`: high COM allocations left the lower free block marked `Z`, truncating later MCB walks.
- The same review identified that kernel growth had no assembly-time guard against overlapping fixed buffers or the boot relocation source/destination assumptions.
- `detect_device_path` read three filename bytes before checking whether a short path component had already ended.

### Confirmed Facts

- New `tests/programs/highmcb.asm` direct-boots as a COM target and inspects the initial MCB chain. Before the fix it failed with `FAIL: HIGHMCB FIRST SIG`; after marking the lower split block as `MCB_SIG_M`, it passes.
- `src/memory.inc` now shares `LOAD_SEG`, `RELOC_SEG`, `SEC_BUF`, `ENV_SEG`, and `MCB_START` across boot/kernel/test assembly.
- `src/kernel.asm` now has build-time `%error` checks for load/relocation ordering, boot relocation gap size, `SEC_BUF` overlap, and `ENV_SEG` ordering/overlap.
- `detect_device_path` now checks for a null terminator before each device-name character read, preserving device behavior while avoiding short-component overreads.
- `tests/programs/devnames.asm` now checks that drive/root-only strings do not open as devices and that a real `CONSOLE.DAT` file is opened normally.

### Tests And Probes Run

- `python3 scripts/test_highmcb.py` fails before the MCB fix and passes after it.
- `python3 scripts/test_devnames.py` passes with short-path and `CONSOLE.DAT` coverage.
- `python3 -m py_compile scripts/test_highmcb.py scripts/test_devnames.py` passes.
- `make test` passes with `scripts/test_highmcb.py` included.
- `git diff --check` passes.

## 2026-05-25 Phase 17 DOS Device Names

### Symptoms

- `scripts/test_devnames.py` passed for direct-boot `DEVNAMES.COM`, but shell-launched COM programs regressed after adding DOS device handles.
- `scripts/test_envpath.py` printed binary garbage at `A:\>envtest`, exited with code `01`, and missed `PASS: ENVTEST`/`PASS: PATHRUN`.
- `scripts/test_shell.py` reached `A:\>hello` and then stalled before `PASS: HELLO.COM`, eventually timing out waiting for `READY: EXTKEY`.

### Confirmed Facts

- The device-name handler now recognizes `CON`, `NUL`, `AUX`, and `PRN` case-insensitively and before normal file lookup for `AH=3Ch`/`AH=3Dh`.
- `CON` and `NUL` are represented as ordinary handle-table entries with `H_DIR_LBA=0` and a device type in `H_DIR_OFF`; `NUL` reads EOF and accepts writes, while `CON` reads/writes through the console path.
- Unsupported `AUX`/`PRN` are recognized but return access denied (`AX=5`) instead of falling through to ordinary file lookup.
- The shell/EXEC regression was not caused by device I/O. Phase 17 grew `kernel_end` past the old relocation gap from boot `LOAD_SEG=0x0800` to `RELOC_SEG=0x0340`; boot-time relocation could overwrite the source instruction stream after `rep movsb`.
- Moving the boot load segment to `0x1000` makes the source and relocated destination non-overlapping for the current kernel size and fixed the dynamic COM corruption.
- Review found that device reads branched before `rf_read` was reset, so a file read could leak a stale byte count into later `NUL`/`CON` reads. `rf_read` is now cleared before the device branch, and `DEVNAMES.COM` reads `NUL` after a real file read to cover it.

### Tests And Probes Run

- `python3 scripts/test_devnames.py` passes and covers `NUL` open/create write/read, confirms `AH=3Ch NUL` does not create a real root directory entry, `CON` write/read, unsupported `PRN`/`AUX`, extension/case-insensitive device names, a normal `NULFILE.DAT` lookup, and `NUL` read after real file I/O.
- `python3 scripts/test_envpath.py` failed before the load-segment move and passes after it.
- `python3 scripts/test_shell.py` failed before the load-segment move and passes after it.
- `python3 scripts/test_boot.py` passes after the boot load-segment move.
- `make test` passes with `scripts/test_devnames.py` included.
- `git diff --check` and `python3 -m py_compile scripts/test_devnames.py` pass.

## 2026-05-25 Phase 16 AUTOEXEC Startup

### Symptoms

- Minimal `.BAT` execution already worked interactively, but the shell did not run `AUTOEXEC.BAT` during startup.
- `scripts/test_autoexec.py` initially booted to `A:\>` and exited without printing any `AUTOEXEC.BAT` output.

### Confirmed Facts

- `scripts/test_autoexec.py` builds a shell image containing `AUTOEXEC.BAT` with `ECHO`, `REM`, a blank line, `MD`, `CD`, a `HELLO.COM` child launch, a bad command, and a final `ECHO` marker.
- Before the fix, the regression missed `AUTOEXEC START`, `IN STARTUP DIR`, `PASS: HELLO.COM`, `Bad command or file name`, and `AUTOEXEC DONE`.
- The shell now calls `run_autoexec` after printing the banner and before entering the interactive prompt.
- Missing `AUTOEXEC.BAT` remains non-fatal because `run_batch_named` returns carry on open failure and startup ignores that status.
- A bad command inside the startup batch prints `Bad command or file name`, then batch execution continues to the following line and returns to the interactive prompt.
- `run_autoexec` normalizes carry before returning so missing `AUTOEXEC.BAT` does not leak status into the prompt path.
- Nested `.BAT` execution is still unsupported, but `run_batch_named` now rejects nested batch entry while a batch is active instead of overwriting the active `batch_buf` state.

### Tests And Probes Run

- `python3 scripts/test_autoexec.py` fails before the fix and passes after startup runs `AUTOEXEC.BAT`.
- `scripts/test_autoexec.py` also covers the no-`AUTOEXEC.BAT` startup path and asserts that no file-not-found diagnostic is printed.
- `python3 scripts/test_shell.py` passes, covering the no-`AUTOEXEC.BAT` startup path and existing interactive batch behavior.
- `make test` passes with `scripts/test_autoexec.py` included.
- `git diff --check` and `python3 -m py_compile scripts/test_autoexec.py` pass.

## 2026-05-25 Phase 15 Environment And PATH

### Symptoms

- The shell could launch programs from the current directory, but not through `PATH` when the current directory changed.
- Child programs received an environment segment whose block contained only the double-null terminator and executable path tail, so `COMSPEC`, `PATH`, and `PROMPT` were absent.

### Confirmed Facts

- `scripts/test_envpath.py` initially failed with `FAIL: ENVTEST COMSPEC` and `Bad command or file name` for `PATHRUN` from `A:\WORK`.
- The kernel now writes `COMSPEC=<drive>:\SHELL.COM`, `PATH=<drive>:\;<drive>:\BIN`, and `PROMPT=$P$G` before the double-null terminator for both the boot shell and `EXEC` children.
- `update_exec_environment_path` still writes the DOS executable-path tail after the double-null terminator, using the current drive/current directory logic already used for child path reporting.
- The shell now tries current directory `.COM`, `.EXE`, and `.BAT` first, then searches each `PATH` element from the PSP environment when the command name has no explicit drive or directory component.
- A failed interim run exposed a bug in the new `ENVTEST.COM` helper: after skipping `COMSPEC`, it advanced its search key and looked for `ATH=` instead of `PATH=`. The helper now preserves the original key pointer across environment strings.

### Tests And Probes Run

- `python3 scripts/test_envpath.py` failed before the fix and passes after the environment/PATH implementation.
- `python3 scripts/test_shell.py` passes after the shell lookup changes.
- `make test` passes with `scripts/test_envpath.py` included.
- `git diff --check` and `python3 -m py_compile scripts/test_envpath.py` pass.

## 2026-05-25 Review Follow-Up: Close Written Handles On Termination

### Symptoms

- Reviewers flagged that a program could create/write a file and terminate without closing the handle, leaving FAT and directory-entry updates unflushed.

### Confirmed Facts

- `scripts/test_termflush.py` boots `tests/programs/termflush.asm`, which creates `TERMOUT.DAT`, writes a payload, prints `PASS: TERMFLUSH`, and exits through `INT 21h AH=4Ch` without closing the handle.
- Before the fix, the program exited successfully but host FAT inspection found `TERMOUT.DAT` with size `0` instead of `27`.
- Handle records now include an owner PSP field. `AH=3Ch`/`AH=3Dh` assign owner `cur_psp`, explicit close clears the owner, and `do_terminate` flushes/closes handles owned by the terminating PSP before freeing its memory or restoring the parent PSP.
- Parent-owned or kernel-owned handles are not closed during a child termination because the sweep only closes handles whose owner matches the current PSP.

### Tests And Probes Run

- `python3 scripts/test_termflush.py` fails before the fix with `FAIL: TERMOUT.DAT size 0, expected 27` and passes after the fix.
- `make test` passes with `scripts/test_termflush.py` included.

## 2026-05-25 Review Follow-Up: Directory Extension Rollback

### Symptoms

- Reviewers flagged that subdirectory extension links a newly allocated cluster into the FAT chain before zeroing and writing that cluster.
- If the zero-sector write fails, a later FAT flush can persist the extended directory chain even though the original create/mkdir returned an error.

### Confirmed Facts

- `scripts/test_dirextfail.py` builds a fault-injection kernel with `TEST_DIR_EXT_ZERO_FAIL`, fills `FULLDIR` so the next create must extend it, forces the first extension zero-sector write to fail, then closes a root file to force a later FAT flush.
- Before rollback, the DOS program reported `PASS: DIREXTFAIL`, but host FAT inspection found `FULLDIR` extended from one cluster to `[40, 55]`.
- `find_dir_free` now stores the old FAT EOC marker before linking the new cluster. On zero-sector write or FAT flush failure after extension, it restores the old link and clears the newly allocated cluster in the in-memory FAT before returning failure.

### Tests And Probes Run

- `python3 scripts/test_dirextfail.py` fails before the rollback with `FAIL: FULLDIR chain was extended after failed write` and passes after the fix.
- `make test` passes with `scripts/test_dirextfail.py` included.

## 2026-05-25 Review Follow-Up: INT 21h Register Preservation

### Symptoms

- Reviewers flagged additional DOS API handlers that could still clobber caller-visible registers after the Simon `AH=48h` allocator fix.
- The highest-risk paths were `AH=3Dh` open, `AH=3Eh` close, `AH=43h` get/set attributes, and `AH=49h` free memory.

### Confirmed Facts

- `scripts/test_regpres.py` boots `tests/programs/regpres.asm`, which sets sentinel values in `ES`, `BX`, `CX`, `DX`, `SI`, and `DI` across the flagged calls, including representative success and error paths.
- Before the fix, the regression failed immediately with `FAIL: REGPRES OPEN REGS` because `AH=3Dh` did not preserve the caller's `ES`/`DX` across `resolve_path`/handle setup.
- `AH=3Eh` non-stdio close paths could clobber `CX`, `DX`, and `SI` while converting the handle to a table offset and flushing writable handles.
- `AH=43h` get/set attribute paths did not preserve `ES`/`DX` around `resolve_path`; get-attribute errors also needed to restore caller `CX`, while success still returns attributes in `CX`. `AH=43h/1` also returned success without writing the new attribute byte.
- `AH=49h` used `ES`, `DI`, and `CX` while walking/merging MCBs and now restores them before returning.

### Tests And Probes Run

- `python3 scripts/test_regpres.py` failed before the fix with `FAIL: REGPRES OPEN REGS` and passes after the fix.
- `make test` passes with `scripts/test_regpres.py` included.

## 2026-05-25 Review Follow-Up: FindFirst Attribute Filtering

### Symptoms

- Reviewers flagged that `FindFirst`/`FindNext` filtered only volume-label entries and could return hidden, system, or directory entries even when the search mask did not request them.

### Confirmed Facts

- `scripts/test_findattr.py` builds an image with normal, hidden, system, directory, and volume-label entries.
- Before the fix, the test failed with `FAIL: FINDATTR MISSING` because an entry that should have been filtered out was returned.
- `find_in_dir` remains unfiltered for ordinary path resolution except for the existing volume-label exclusion, while `FindFirst`/`FindNext` use a filtered search path that applies the active DTA/search attribute mask.
- Review of the initial fix found that unfiltered path resolution could match volume-label entries; `find_in_dir` now skips volume labels again, and the regression tries to open the volume-label name to ensure it fails.

### Tests And Probes Run

- `python3 scripts/test_findattr.py` initially failed with `FAIL: FINDATTR MISSING`; after extending the regression, it failed with `FAIL: FINDATTR VOLUME OPEN` until unfiltered lookups skipped volume labels again.
- `python3 scripts/test_findattr.py` passes after the fix.
- `make test` passes with `scripts/test_findattr.py` included.

## 2026-05-25 Review Follow-Up: FindFirst Timestamps

### Symptoms

- Reviewers flagged that `store_find_dta` returned zero time/date fields for all `FindFirst`/`FindNext` matches.

### Confirmed Facts

- `scripts/test_findtime.py` creates `TIMECHK.DAT`, closes it, then calls `FindFirst` and expects DTA offsets `+22` and `+24` to match the directory entry values `FAT_TIME` and `FAT_DATE`.
- Before the fix, the test failed with `FAIL: FINDTIME TIME` because DTA time/date were zero.
- `find_in_dir` now captures matched directory entry time/date and `store_find_dta` writes those values to the DTA.

### Tests And Probes Run

- `python3 scripts/test_findtime.py` fails before the fix and passes after the fix.
- `make test` passes with `scripts/test_findtime.py` included.

## 2026-05-25 Review Follow-Up: FindNext And SEC_BUF Cache

### Symptoms

- Reviewers flagged `FindNext` continuing searches from kernel globals instead of the active DTA, which could corrupt interleaved directory searches.
- Reviewers also flagged a remaining stale `SEC_BUF` cache path where code could overwrite `SEC_BUF` directly before `write_sector`, bypassing the previous `read_sector` cache invalidation fix.

### Confirmed Facts

- `scripts/test_findnext.py` initially failed with `FAIL: FINDNEXT NEXT TXT`: after `FindFirst("*.TXT")`, an interleaved `FindFirst("Z*.COM")`, and restoring the original DTA, `FindNext` did not continue the original TXT search.
- `FindNext` now restores the search template, attribute mask, directory cluster, and prior entry index from the active DTA before calling `find_in_dir_from`.
- `scripts/test_readcache.py` was extended to read a cached file sector, create a directory that fills `SEC_BUF`, and reread the same file sector; it initially failed with `FAIL: READCACHE DATA`.
- `write_sector` now invalidates `rf_cache_valid`, covering direct `SEC_BUF` overwrite paths before the buffer is written.

### Tests And Probes Run

- `python3 scripts/test_findnext.py` failed before the fix and passes after the fix.
- `python3 scripts/test_readcache.py` failed before the `write_sector` invalidation and passes after the fix.
- `make test` passes with both regressions included.

## 2026-05-25 MI2 Load Invalid Saved Game

### Symptoms

- User reported MI2 saved-game loading was intermittent and provided a screenshot showing `Invalid Saved Game (4379, 8224)` while loading slot 3 `rtrst`.
- `4379` is `0x111B`, matching the save-file header word at offset `0x28`; `8224` is `0x2020`, two spaces.

### Confirmed Facts

- `SAVEGAME.003` in `build/games_hd_all.img` starts with name `rtrst`, has `0x111B` at offset `0x28`, and does not contain `0x2020` in its early data.
- Reproduced the screenshot under QEMU by opening MI2, selecting Load, and clicking slot 3.
- A traced image showed the load dialog scans each save with `READ REQ=0028 POS=00000000` followed by `READ REQ=0002 POS=00000028`; during the actual load of `SAVEGAME.003`, the second read returned count `2` but the target word was `0x2020`.
- Temporary source/destination tracing showed `SEC_BUF` itself contained `0x2020`, so this was not a copy-to-application-buffer issue.
- Root cause: the read-file sector cache marked `SEC_BUF` as containing the save file's data sector, but later directory scanning during `open_file` reused `SEC_BUF` without clearing `rf_cache_valid`. Reopening the same save then skipped the disk read and copied stale directory-sector bytes.

### Tests And Probes Run

- Manual QEMU load-slot-3 reproduction produced the invalid-save dialog before the fix.
- After invalidating `rf_cache_valid` in `read_sector`, the same slot loads past the invalid-save check and reaches MI2's `Sound Card Changed... may invalidate savegame` warning.
- `scripts/test_readcache.py` covers the stale-cache pattern with a small subdirectory file: read magic word, close, reopen, read the same word again.

## 2026-05-24 AH=36h Disk-Free Reporting

### Symptoms

- `INT 21h AH=36h` returned total data clusters in both `BX` and `DX`, so callers could not distinguish free space from total capacity.

### Confirmed Facts

- A new regression in `tests/programs/diskfree.asm` deletes any stale `FREECHK.DAT`, calls `AH=36h`, writes a 600-byte file, calls `AH=36h` again, verifies requested-drive handling, deletes the file, and verifies free clusters return to the original count.
- Before the fix, `python3 scripts/test_diskfree.py` failed with `FAIL: DISKFREE FREE` because `BX >= DX` on a non-empty image.
- The fixed handler validates the requested drive, scans FAT entries from cluster 2 up to `kmax_cluster`, counts zero entries into `BX`, returns total clusters in `DX`, sectors per cluster in `AX`, and bytes per sector from the BPB in `CX`.

### Tests And Probes Run

- `python3 scripts/test_diskfree.py` now passes.
- `make test` now includes `scripts/test_diskfree.py` and passes.

## 2026-05-24 MI2 Save-Game Automation

### Symptoms

- User reported full Monkey Island 2 save games appear not to work correctly.
- Manual QEMU probing reached the MI2 save dialog, but clicking `OK` after entering a new slot-2 name produced `The game was NOT saved (disk full?)` and no `SAVEGAME.002` appeared in `C:\MI2`.

### Confirmed Facts

- Full MI2 can still be driven to the F5 save/load overlay from `build/games_hd_all.img` using the current QEMU monitor flow.
- The bundled full MI2 files already include `SAVEGAME.001` with display name `123`; this is why slot 1 appears pre-populated in the save UI.
- A new automated probe in `scripts/test_mi2_save.py` rebuilds `build/games_hd_all.img`, drives full MI2 to the save dialog, selects slot 2, types `auto`, clicks `OK`, and then inspects the FAT image for `C:\MI2\SAVEGAME.002` with an `auto` name prefix.
- Current result after the BPB geometry fix: `python3 scripts/test_mi2_save.py` passes and creates `SAVEGAME.002`.
- Diagnostic screenshots from the original failing run are `build/mi2_save_dialog.ppm` and `build/mi2_save_after_ok.ppm`; the latter showed `The game was NOT saved (disk full?)` with slot 2 containing `auto_`.
- The generated `hd20m` all-games FAT image is not actually full after the failing run: it has 218 free clusters, about 1.7 MB free with 16 sectors per cluster.
- Temporary create/write/FAT tracing showed MI2 successfully created `SAVEGAME.002`, but the first write returned zero bytes because `fat_alloc_cluster` found no free clusters below an incorrect `kmax_cluster=0x08E1`.
- Root cause: `init_bpb_geometry` lost `bx=bpb_copy` while calculating root directory sectors, so it read total sectors from stale offset `0x0200+19` instead of the BPB copy. Restoring `bx` before reading total sectors gives the correct FAT cluster range.

### Tests And Probes Run

- `python3 scripts/build_games_hd_all.py` rebuilt the all-games image before each probe.
- Focused save-dialog probes confirmed the correct input sequence to reach the save UI: launch `C:\MI2\MONKEY2`, type `1234`/Enter at the copy-protection flow, click the top `all the puzzles` choice, skip intro with `Esc`, press `F5`, then click `Save`.
- `python3 scripts/test_mi2_save.py` originally failed with `FAIL: MI2 did not create C:\MI2\SAVEGAME.002`.
- A direct FAT scan after the failure counted `clusters=2518`, `used=2300`, `free=218`, so the in-game `disk full?` message is likely reporting a failed save path, not literal media exhaustion.
- After restoring `bx=bpb_copy` in `init_bpb_geometry`, `python3 scripts/test_mi2_save.py` passes with `SAVEGAME.002 created, size=31358`.

### Follow-Ups

- Verify load behavior separately; this test only proves that a new save file is created and receives the expected display-name prefix.
- Keep `scripts/test_mi2_save.py` standalone for now because it is long-running and requires the full MI2 vendor archive.

## 2026-05-24 Simon RUNVGA Memory Compatibility

### Symptoms

- After minimal BAT support, `C:\SIMON\SIMON.BAT` could launch `RUNVGA GDEMO /3`, but Simon either returned to the shell or crashed before a stable VGA frame.
- A lower-resident-memory build reached `GDEMO` reads and then hit `EXC 06 at 1607:0FA8`; the bytes at that address were ASCII text from resource data, indicating execution had been redirected into data.
- `RUNVGA.EXE` has `MaxAlloc=FFFF`; LainDOS previously allocated only the computed minimum/image size for EXE loads.
- After the RUNVGA path worked, `C:\SIMON\SETUP.EXE` printed `Packed file is corrupt` and returned to the shell.

### Confirmed Facts

- DOSBox-X comparison showed `RUNVGA.EXE` resizing its PSP block to `0x416D` paragraphs and then opening/reading `GDEMO`.
- LainDOS now honors EXE MZ `MaxAlloc` for both boot-time EXE loads and `INT 21h AH=4Bh` EXEC. `MaxAlloc=FFFF` uses the largest free MCB; finite values are capped by the largest available block and never below the minimum/file load size.
- Lowering resident buffers made enough conventional memory available for Simon without the unstable partial bootloader low-load experiment. Current layout keeps the kernel loaded at `0x0800`, self-relocates it to `0x0340`, uses boot FAT/root buffers at `0x0060`/`0x0180`, runtime buffers at `0x0840`/`0x0860`, and starts the DOS MCB arena at `0x1000`.
- The partial bootloader low-load experiment was abandoned because it caused BIOS read failure/hang after 8 kernel sectors.
- `GDEMO` data corruption was ruled out: host checksums for the first 12 sectors matched the runtime buffer dump, and Simon's first 512-byte `GDEMO` read matched the host file exactly.
- Root cause of the Simon `EXC 06`: `INT 21h AH=48h` clobbered non-return registers while splitting MCBs, especially `ES`, `DI`, `CX`, and `DX`. Simon depended on those registers surviving allocation calls.
- `AH=48h` now preserves non-return registers on success and failure while still returning `AX` on success and `AX/BX` on failure. `MEMREG.COM` verifies `ES/BX/CX/DX/DI` preservation on success.
- Successful `AH=4Ah` resize of a PSP-owned block now updates `PSP:0002` to the new top-of-memory value. `MEMREG.COM` verifies this.
- Existing EXE tests with `MaxAlloc=FFFF` consumed the whole arena under the corrected loader behavior; their MZ headers were narrowed to finite maxalloc values where the test body still needs later DOS heap allocations.
- Added minimal compatibility stubs for DOS probes seen during Simon bring-up: `AH=0Eh` select disk and `AH=36h` disk free. The IOCTL get-device-info file path returns the current drive in the low bits of `DX`, with bit 7 clear for disk files.
- `SETUP.EXE` is a packed EXE whose decompressor normalizes backward source pointers by subtracting about `0x0FFF` paragraphs. With `MCB_START=0x0900`, shell-launched EXEs loaded around `0x0911`, causing the decompressor's source segment to wrap to `0xFEA6` and take its corrupt-file branch. Raising `MCB_START` to `0x1000` keeps the load segment around `0x1011` and avoids the wrap while preserving enough memory for RUNVGA.
- Added `PACKSEG.EXE` to the shell regression to verify shell-launched EXEs load at or above segment `0x1000`, protecting the setup packer requirement.

### Tests And Probes Run

- `make test` initially failed after MaxAlloc support because `MEMTEST.EXE` and later `READWRAP.EXE` requested all remaining memory before making explicit `AH=48h` allocations. Updating their MZ maxalloc values fixed those regressions.
- Final `make test` passes, including `PASS: EXEMAX`, `PASS: MEMREG`, `PASS: PACKSEG`, and `PASS: READWRAP`.
- `python3 scripts/test_monkey_full.py` passes with framebuffer activity: `111 colors`, `209876 nonblack pixels`.
- `python3 scripts/build_games_hd_all.py` rebuilt `build/games_hd_all.img` with the current kernel.
- Focused QEMU/VNC Simon smoke booted `build/games_hd_all.img`, ran `CD SIMON`, `SIMON`, and captured `build/simon_review.ppm`: PPM `640x400`, `77 colors`, `219128` nonblack pixels, with no `EXC` in serial output.
- Focused QEMU/VNC setup smoke booted `build/games_hd_all.img`, ran `CD SIMON`, `SETUP`, and reached the `Simon the Sorcerer Setup` music-card menu without `Packed file is corrupt` or `EXC`; `build/simon_setup_final.ppm` captured a `720x400` text screen with `4922` nonblack pixels.
- Focused QEMU/VNC Simon smoke after raising `MCB_START` captured `build/simon_after_setupfix.ppm`: PPM `640x400`, `77 colors`, `219128` nonblack pixels, with no `EXC` in serial output.

### Failed Or Weakened Hypotheses

- Not caused by corrupted `GDEMO` FAT reads; checksums and runtime buffer dumps matched host bytes.
- Not fixed by changing DOS version to `AX=0005`.
- Not fixed by read/alloc ZF return experiments.
- INT 21h internal stack switching was not a safe quick fix; the attempted version broke existing COM return flow and was reverted.
- The setup failure was not actual file corruption; it was the packed decompressor's low-segment wrap caused by loading the EXE too low.

### Follow-Ups

- Run a code review before committing the current memory/Simon compatibility changes.
- Preserve `EXEMAX.EXE`, `MEMREG.COM`, and `PACKSEG.EXE` in the shell regression so EXE MaxAlloc, allocator register preservation, and packed-EXE load segment compatibility do not regress.
- Actual Monkey/MI2/Simon save-load behavior still needs separate interactive verification.
- `MCB_START=0x1000` leaves about 28 KB more gap above the fixed runtime buffers than `0x0900`; if a future game needs that memory, first consider moving `SEC_BUF`/`ENV_SEG` upward or representing the low reserved area explicitly.

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
- Added `tests/programs/closetest.asm` to verify double-close behavior; temporary image output included `PASS: CLOSE`.
- Added `tests/programs/regtest.asm` to verify `AH=3Fh` register preservation; it failed before the fix with `FAIL: REGS CLOBBER` and passed after preserving `DX`.
- Fixed `AH=3Fh` to preserve `DX`; Monkey still stops after the same `disk01.lec` `0x03F5` read and VGA screendump remains all black.
- Extended `tests/programs/regtest.asm` to verify `AH=42h` preserves `SI`; it failed before the fix with `FAIL: REGS CLOBBER` after a seek and passed after preserving `SI`.
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

- Added `tests/programs/mousetest.asm` for the software `INT 33h` API: reset/install, set/get position, range clamping, show/hide, button press query, and motion counters.
- Added a built-in `INT 33h` state machine for `AX=0000`, `0001`, `0002`, `0003`, `0004`, `0005`, `0007`, `0008`, `000B`, and `000C` callback address storage.
- Added PS/2 mouse initialization and packet decoding for standard 3-byte packets.
- Added an IRQ12 handler at `INT 74h` that feeds mouse bytes into the packet decoder and sends EOIs to both PICs.
- Added `tests/programs/mousehw.asm`, an optional hardware probe that waits for non-zero motion from `INT 33h AX=000B`.

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
- `tests/programs/bigreloc.asm` reproduced the relocation-buffer overflow before the fix: it emitted an unexpected `OPEN TESTFILE.DAT` trace and failed to open the file because the handle table was corrupted.
- MI2 does not call `INT 21h AH=58h` allocation strategy before its sound overlay allocation. It shrinks its PSP, allocates a tiny `0x001A` paragraph block, then tries to grow the PSP again. Placing tiny allocations high preserves enough low free space for this pattern.
- The sound overlay file lookup succeeds: trace showed `OPEN A:\null.ims -> H=0005 SIZE=00000380`.
- `NULL.IMS` is an MZ-format overlay. The exact `Error 1 loading sound overlay` matched LainDOS returning `AX=0001` from the previously stubbed `AH=4Bh` handler.

### Fixes Made During Investigation

- Added `scripts/build_mi2.py` and 2.88 MB FAT12 geometry support in `scripts/mkimage.py`.
- Fixed `src/boot.asm` to load every sector in a FAT cluster instead of assuming one sector per cluster.
- Added `INT 21h AH=40h` std-handle write support for runtime error output and `tests/programs/writetest.asm` coverage.
- Added a DOS environment executable path via `init_environment`, allowing MI2 to derive `MI2DEMO.000` instead of `.000`.
- Replaced fixed-buffer MZ relocation saving in `setup_exe_dyn` with in-place relocation before copy-down; removed `reloc_buf`.
- Added `tests/programs/bigreloc.asm` plus `scripts/test_bigreloc.py` to cover EXEs with more relocation entries than the old buffer.
- Added `INT 21h AH=0Bh` stdin status and `AH=08h` direct character input via BIOS `INT 16h`; added `tests/programs/keytest.asm` and `scripts/test_keyboard.py` for no-key status coverage.
- Implemented `AH=58h` get/set return behavior correctly and added first/best/last fit allocation paths. Tiny default allocations now use high placement to avoid blocking immediate PSP regrowth.
- Extended `tests/programs/memtest.asm` with last-fit allocation strategy coverage.
- Added minimal `INT 21h AH=4Bh AL=03h` overlay loading for MZ overlays: copy the image portion to the caller-provided load segment and apply relocations using the caller-provided relocation factor.
- Added `tests/programs/ovltest.asm`, `tests/programs/overlay.asm`, and `scripts/test_overlay.py` to verify overlay load and relocation behavior.

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
- Added `tests/programs/exectest.asm` so the shell regression covers nested EXEC (`SHELL.COM` -> `EXECTEST.COM` -> `HELLO.COM`).
- Fixed COM allocation-size arithmetic to carry through `DX`, cleared `AH=4Dh` return code after retrieval, and skipped deleted/volume-label entries in wildcard directory searches.
- Added basic DTA search-state fields for FindFirst and made volume-label filtering depend on the search attribute mask.

### Tests Run

- `python3 scripts/test_shell.py` passed after the fix.
- `make test` passed, including the new shell regression.
- `python3 scripts/test_shell.py` passed again after adding `DIR`, bad-command, repeated child EXEC, and nested EXEC coverage.
- `make test` passed again after the review fixes.
- `python3 scripts/test_shell.py` and `make test` passed again after DTA search-state and volume-attribute-mask adjustments.
- `python3 scripts/build_mi2.py` rebuilt `build/mi2.img`; a 15-second QEMU serial smoke found `LainDOS booted` and `EXE loaded` with no `EXC `, runtime error, unhandled `INT 21h`, or `Error 1 loading sound overlay` markers.
- `python3 scripts/build_monkey.py` rebuilt `build/monkey.img`; a 15-second QEMU serial smoke found `LainDOS booted` and `EXE loaded` with no `EXC `, runtime error, unhandled `INT 21h`, or `File not found` markers.

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
- Added `tests/programs/consoletest.asm` and `scripts/test_console.py`; wired the console test into `make test`.
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
- Added `tests/programs/savewr.asm` and `scripts/test_savewrite.py`; the test writes a 700-byte pattern across two clusters, closes, reopens, verifies date/time and contents, renames the file, and verifies the mutated disk image on the host.
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
- Exact 40/16/32 geometry starts in Bochs, but QEMU hard-disk boot then fails before LainDOS prints `LainDOS booted`.
- A 20/16/63 geometry with 20,160 total sectors preserves the QEMU hard-disk boot path and fits Bochs' geometry check.
- Timed-out Bochs runs can leave an image lock behind, so the launcher boots a per-run copy of `build/monkey_full.img` and removes that copy after Bochs exits.

### Fixes Made During Investigation

- Added `scripts/run_monkey_full_bochs.py` to build the full Monkey image, generate `build/monkey_full.bochsrc`, and launch Bochs with SDL2 VGA output by default.
- Added `mise run run-monkey-full-bochs` for interactive Bochs launch.
- Added COM1 file logging and a `--smoke-seconds` mode for bounded non-interactive Bochs startup checks that require the `LainDOS booted` serial marker.

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
## 2026-05-28 Ascendancy Play Screen Input Probe

### Symptoms

- User reported Ascendancy now reaches the play screen under 86Box but does not appear to react.
- Initial suspicion is mouse/input rather than QEMU's known Ascendancy x87 stall, because this needs the 86Box path and QEMU is already known unreliable for this game.

### Confirmed Facts

- `/Applications/86Box.app/Contents/MacOS/86Box` exists on this host.
- `vendor/Ascendancy_1995.zip` is present locally, and `python3 scripts/build_games_hd_all.py` rebuilt `build/games_hd_all.img` with the mouse-callback kernel.
- Recreated the isolated 86Box profile under `build/86box-serial-file/` from the local `monkey` 86Box VM config/NVR, with `gfxcard = s3_trio64_pci`, PS/2 mouse, and COM1 on stdio.
- Before this fix, built-in INT 33h support stored `AX=000Ch` callback state (`mouse_callback_mask`, `mouse_callback_off`, `mouse_callback_seg`) but never invoked the callback from PS/2 packet handling.
- Phase 8 mouse notes explicitly left callback invocation as future compatibility work if another program requires it.
- Implemented generic `INT 33h AX=000Ch` callback invocation on motion and left/right press/release events, with callback re-entrancy guard and callback cleanup on reset/process termination.
- User-assisted 86Box Ascendancy run confirmed the mouse now works at the play screen, but movement was weirdly slow.
- Added `INT 33h AX=000Fh` mickey/pixel ratio support. Position deltas are scaled by signed `delta * 8 / ratio` with signed remainders; raw motion counters and callback SI/DI remain raw mickeys.
- Follow-up review noted callback SI/DI should be per-event rather than cumulative, so callback invocation now passes per-packet deltas while `AX=000Bh` keeps cumulative-since-last-query behavior.
- Ratio inputs are clamped to nonzero values at or below 2048 to avoid bad guest input causing `idiv` faults or signed overflow.
- User-assisted 86Box retest with `AX=000Fh` support confirmed Ascendancy mouse speed feels much better.
- User reported mouse wraparound in multiple games: moving left past the minimum appeared at the right edge, and moving up past the minimum appeared at the bottom edge.
- Root cause: scaled signed deltas were added directly into unsigned `mouse_x`/`mouse_y`, then the unsigned clamp saw underflowed values like `0xFFFF` and clamped them to the maximum edge.
- Fixed position updates to apply scaled deltas through signed saturating helpers for X/Y before the final range clamp.
- Extended `scripts/test_mouseratio.py`/`tests/programs/mouseratio.asm` with top-left and bottom-right edge regressions. The top-left case failed before the saturating add fix with `FAIL: MOUSERATIO EDGE` and passes after.
- Current normal kernel size is `22488` bytes. A temporary attempt to move `SEC_BUF`/`ENV_SEG` to `0x08E0`/`0x0900` for more headroom caused an early `EXC 06` because `ENV_SEG=0x0900` collides with the kernel stack top at `CS:5C00`; that layout was reverted.

### Tests Run

- `python3 scripts/test_mousecb.py`
- `python3 scripts/test_mouseratio.py`
- `python3 -m py_compile scripts/test_mousecb.py scripts/test_mouseratio.py scripts/run_tests.py`
- `git diff --check`
- `make test` (`34/34` passed)
- `python3 scripts/build_games_hd_all.py`

### Next Probes

- Run a short 86Box smoke with the rebuilt `build/games_hd_all.img` if more manual validation is needed.
- If any game still has odd mouse behavior, add targeted tracing for its `INT 33h` setup calls and consider the next generic mouse-driver functions (`AX=0013h` double-speed threshold or `AX=001Ah/001Bh` sensitivity) rather than app-specific fixes.

## 2026-05-28 Duplicate Handle API Regression Work

### Confirmed Facts

- Added `INT 21h AH=45h/46h` support with shared root handles, alias slots, and root refcounts so duplicate file handles share file position and close lifetime.
- Initial `tests/programs/duptest.asm` failed with unhandled `INT 21h AH=45`; after implementation it verifies shared position, closing the original while aliases remain, forced duplication, bad-handle errors, forced duplicate over an aliased root, and forcing an alias back into a closed root slot.
- The first full-suite run exposed `WRITE-STDERR` missing because standard-handle table checks used `mul` without preserving caller `DX`; preserving `DX` fixed `scripts/test_write.py`.
- The next full-suite run exposed `FAIL: REGPRES IOCTL REGS` because IOCTL table paths returned with caller `SI` clobbered by `resolve_handle_for_use`; preserving `SI` fixed `scripts/test_regpres.py`.
- Review highlighted the closed-root revival path and same-handle standard-slot validation. `DUPTEST` now covers revival, and `AH=46h BX==CX` validates explicit table entries for handles below 5 while preserving implicit CON behavior for unused standard slots.
- To keep the enlarged kernel below scratch buffers, the sector buffer moved to `0x0980`, environment to `0x09A0`, and root buffer to `0x09C0`. The default kernel is currently `24707` bytes and the EMS-enabled kernel is `25289` bytes.

### Tests Run

- `python3 scripts/test_dup.py`
- `python3 scripts/test_write.py`
- `python3 scripts/test_regpres.py`
- `python3 scripts/test_savewrite.py`
- `python3 scripts/test_termflush.py`
- `python3 scripts/test_readwrap.py`
- `python3 scripts/test_console.py`
- `python3 scripts/test_shell.py`
- `make test` (`38/38` passed)

## 2026-05-28 Commit File API

### Confirmed Facts

- Added `tests/programs/committest.asm` / `scripts/test_commit.py` for `INT 21h AH=68h` commit-file behavior.
- Before implementation the test failed with unhandled `INT 21h AH=68` and `FAIL: COMMIT AH68`.
- `AH=68h` now resolves duplicated handles to the shared root, treats implicit standard handles as successful device commits, flushes directory metadata and FAT for real files, and returns error 6 for invalid handles.
- `COMMITTEST` writes a file, duplicates the handle, commits through the duplicate before closing, reopens it through a second handle to verify committed size/data are visible, checks unused and out-of-range invalid-handle error 6, and checks implicit stdout success.

### Tests Run

- `python3 scripts/test_commit.py`

## 2026-05-28 Create-New, Temp-File, And Handle-Count APIs

### Confirmed Facts

- Added `tests/programs/createapi.asm` / `scripts/test_createapi.py` for `INT 21h AH=67h`, `AH=5Bh`, and `AH=5Ah` compatibility behavior.
- Before implementation the test failed on unhandled `INT 21h AH=67` with `FAIL: CREATEAPI AH67`.
- `AH=67h` now succeeds for nonzero set-handle-count requests as a compatibility no-op; it does not expand LainDOS beyond the fixed `MAX_HANDLES=20` table.
- `AH=5Bh` reuses the normal create path in create-new mode and returns DOS error `80` if the target already exists instead of truncating it.
- `AH=5Ah` appends generated 8.3 `LDxxxx.TMP` names to the caller's path buffer, skips existing collisions, and creates the selected file through create-new semantics.
- `CREATEAPI` verifies `AH=67h` defensive requests, `AH=5Bh` create and exists failure, `AH=5Ah` collision avoidance against an existing `LD0000.TMP`, reopening the generated temp path, generating a distinct second temp path, and preserving the caller's path terminator after a temp-create path error.
- The EMS-enabled build initially exceeded the old `SEC_BUF=0x0980` guard after these handlers. The fixed buffers moved to `SEC_BUF=0x09C0`, `ENV_SEG=0x09E0`, and `ROOT_SEG=0x0A00`, still below the stack/MCB assertions.

### Tests Run

- `python3 scripts/test_createapi.py`

## 2026-05-28 DOS State APIs

### Confirmed Facts

- Added `tests/programs/stateapi.asm` / `scripts/test_stateapi.py` for `INT 21h AH=33h`, `AH=54h`, `AH=2Eh`, `AH=2Bh`, and `AH=2Dh` compatibility state behavior.
- Before implementation the test first failed on missing verify-state handling with unhandled `INT 21h AH=54` / `AH=2E` markers.
- `AH=33h` covers break flag get/set, boot-drive query, and true-version query; `AH=54h` / `AH=2Eh` now get and set the verify flag using the `AH=2Eh` `AL` input.
- `AH=2Bh` now validates and stores the DOS date, including leap-day acceptance and bad-date rejection; `AH=2Ah` returns the stored date. `AH=2Dh` validates and stores explicit time state; `AH=2Ch` returns that state after a set-time call and otherwise keeps the BIOS tick-derived time path.

### Tests Run

- `python3 scripts/test_stateapi.py`

## 2026-05-28 Drive Allocation Data APIs

### Confirmed Facts

- Added `tests/programs/drivedata.asm` / `scripts/test_drivedata.py` for `INT 21h AH=1Bh` and `AH=1Ch` allocation-info compatibility.
- Before implementation the regression failed on unhandled `INT 21h AH=1B` with `FAIL: DRIVEDATA AH1B`.
- `AH=1Bh` now returns allocation data for the default drive. `AH=1Ch` accepts default-drive (`DL=0`) and supported logical drive requests, returns sectors per cluster, bytes per sector, total clusters, and `DS:BX` pointing at the BPB media descriptor byte, and returns `AL=FFh` for invalid drives.

### Tests Run

- `python3 scripts/test_drivedata.py`

## 2026-05-28 Extended IOCTL Compatibility

### Confirmed Facts

- Added `tests/programs/ioctlext.asm` / `scripts/test_ioctlext.py` for additional `INT 21h AH=44h` local IOCTL behavior.
- Before implementation the regression failed at `AX=4401h` with `FAIL: IOCTLEXT SET INFO`.
- `AX=4401h` now validates handles and returns current device information as a compatibility no-op. `AX=4408h` reports removable media for floppy-backed images and non-removable for hard-disk-backed images. `AX=4409h` and `AX=440Ah` report supported drives/handles as local, with invalid-drive and invalid-handle errors preserved.

### Tests Run

- `python3 scripts/test_ioctlext.py`

## 2026-05-29 Date/Time Weekday Size Follow-Up

- Added `DATETIME` coverage for `INT 21h AH=2Ah/2Bh/2Ch/2Dh` weekday and boundary behavior; the first probe failed with `FAIL: DATETIME WEEKDAY` because `AH=2Bh` stored weekday 0 unconditionally.
- Implementing weekday calculation made the EMS-enabled kernel exceed the fixed-buffer guard with `src/kernel.asm:2327: error: kernel overlaps SEC_BUF` during `make test`.
- Preserved the guard and moved the fixed buffers upward by one 512-byte slot: `SEC_BUF=0x09E0`, `READ_CACHE_BUF=0x0A00`, and `ROOT_SEG=0x0A20`; the boot loaders must use the same `ROOT_SEG` because they preload the root directory for the kernel.

## 2026-05-29 Directory Current Edge Semantics

- Added `DIREDGE` coverage for `INT 21h AH=39h/3Ah/3Bh/47h` empty paths, file-as-directory rejection, invalid drive-qualified paths, and current-directory preservation after failed `CHDIR`.
- The first run failed with `FAIL: DIREDGE CD DRIVE` because `AH=3Bh` accepted `Z:\` as root instead of rejecting the unsupported drive.
- Added generic drive-prefix validation for directory path APIs before `AH=39h`, `AH=3Ah`, and `AH=3Bh` resolve or mutate paths.
- `python3 scripts/test_diredge.py` now passes.

## 2026-05-29 FindFirst FindNext Edge Semantics

- Added `FINDEDGE` coverage for `INT 21h AH=4Eh/4Fh` no active search state, no-match/path/drive error codes, drive-qualified root wildcard searches, and exhausted `FindNext` errors.
- The first run failed with `FAIL: FINDEDGE BAD DRIVE` because `FindFirst("Z:\\*.COM")` returned the path-error path instead of invalid-drive error 15.
- Reused path drive-prefix validation for `AH=4Eh` and treated drive-qualified root parents such as `A:\` as root-directory searches.
- `python3 scripts/test_findedge.py` now passes.

## 2026-05-29 Drive-Qualified Relative Paths

- Added `DRIVEPATH` coverage for DOS paths such as `A:LOCAL.TXT`, `A:*.TXT`, and `A:INNER` from a non-root current directory.
- The first run failed with `FAIL: DRIVEPATH OPEN REL` because `resolve_path` treated all drive prefixes as root-qualified.
- Updated path resolution, current-directory path storage, dot-only `CHDIR` traversal, and `FindFirst` bare-name parsing so drive-qualified relative paths stay current-directory-relative while `A:\...` remains root-qualified.
- `python3 scripts/test_drivepath.py` now passes.
- Phase 19 is archived after `make test` passed `65/65`; remaining deliberately deferred APIs are tracked by `Track Deferred DOS Compatibility APIs`.

## 2026-06-05 EXEC Environment Overflow Guard

- The fixed `ENV_PARAS=16` (256-byte) environment block in `update_exec_environment_path` had no destination bound check. A caller-supplied environment larger than ~170 bytes overran the block and corrupted the following MCB.
- Added `ENV_SIZE_BYTES` to `src/memory.inc`, used `bx` as the destination capacity in `update_exec_environment_path`, and inserted a `cmp di, bx / jae .env_overflow` before every `stosb`/`stosw` in the caller-env copy, the path count word, the drive/colon/backslash prefix, the relative-CWD loop, the path copy loop, and the final null terminator.
- On overflow the kernel calls `free_exec_environment` and returns carry, so `load_exec_program` returns `ax=8` and the INT 21h `AH=4Bh` caller sees a clean out-of-memory error with the env block released.
- New `tests/programs/envoflow.asm` allocates 16 paras for a 268-byte caller env, runs `INT 21h AH=4Bh`, and asserts the call returns carry, `ax=8`, and the caller's env can still be freed.
- `scripts/test_envoflow.py` drives the new program and is registered in `scripts/run_tests.py`.
- `make test` passes `77/77`.

## 2026-05-29 Public Demo And Smoke Workflow

- Added `make monkey-demo`, `make run-monkey-demo`, and `make test-monkey-demo` for the shell-boot Monkey Island demo floppy at `build/shell_monkey.img`.
- Renamed the boot serial banner to `LainDOS booted` and updated all tests, docs, and smoke scripts to match.
- Added GitHub Actions CI that installs NASM/QEMU and runs `make test`.
- Verified `make test` passes `65/65` after the rename and drive-path fix.
- Game smoke checks passed: `make test-monkey-demo`, `make test-monkey-full`, `make test-wolf3d-smoke`, and `make test-ascendancy-smoke`.

## 2026-06-07 Ascendancy Mouse Callback Re-entry Regression

- User reported Ascendancy mouse movement regressed after the recent `indos_flag` mouse guard work: movement arrived in short bursts with multi-second pauses, then later appeared not to react at all. Monkey Island 2 still worked.
- A focused `mousedefer` probe initially failed to boot because an 8-character basename needs raw 8.3 `BOOT_FILE` form without a separator (`MOUSDEFRCOM`) and because a far call into a near-returning kernel helper corrupts the caller stack.
- Added test-only far wrapper hooks for mouse callback invocation and replaced the stale hardcoded offsets with NASM-listing-derived offsets in the new `scripts/test_mouseindos.py` regression.
- Root cause: deferring all `INT 33h AX=000Ch` callbacks while `indos_flag != 0` does not match real mouse-driver behavior and starves callback-driven games during frequent or long DOS calls. A one-byte pending flag also collapses multiple mouse packets into one callback.
- Fix: `mouse_invoke_callback` now allows callbacks while DOS is active, keeping only the `mouse_in_callback` recursive-callback guard. `int21_handler` rejects DOS calls made from inside a mouse callback with carry set and `AX=0005`, without touching `indos_flag`.
- An over-broad first attempt rejected every `INT 21h` entry while `indos_flag != 0`; `scripts/test_ascendancy_smoke.py` then failed with `EXC 06` before DOS/4GW because LainDOS `EXEC` runs the child before the parent `AH=4Bh` returns, so child DOS calls legitimately occur with `indos_flag` already set. Narrowing the guard to `mouse_in_callback != 0` fixed the smoke.
- Tests run: `python3 scripts/test_mouseindos.py`, `python3 scripts/test_indos.py`, `python3 scripts/test_mousecb.py`, `python3 scripts/test_mouseratio.py`, and `python3 scripts/test_ascendancy_smoke.py` all pass.

## 2026-06-07 parse_83name Asterisk Wildcards

- Added `scripts/test_findstar.py` / `tests/programs/findstar.asm` to cover FindFirst/FindNext patterns `*`, `B*`, and `*.EXE` against fixture files `A.TXT`, `B`, `B.EXE`, and `C.EXE`.
- The first run failed with `FAIL: FINDSTAR ALL` because a name-part `*` with no explicit dot produced `????????   ` and only matched extensionless entries.
- Updated `parse_83name` so a name-part `*` that reaches end-of-string fills the extension field with `?`, while a following explicit dot still controls extension parsing.
- Focused checks passed: `python3 scripts/test_findstar.py`, `python3 scripts/test_findnext.py`, and `python3 scripts/test_parsefcb.py`.

## 2026-06-07 UTC Offset For DOS Time

- Added build-time `UTC_OFFSET_MINUTES` normalization in `src/kernel.asm`; default is zero and nonzero values are applied modulo 24 hours to BIOS-derived `INT 21h AH=2Ch` results.
- `AH=2Dh` stored DOS time remains unchanged by the offset path because `.gt_stored` returns explicitly set time values.
- Added `scripts/test_timeoffset.py` / `tests/programs/timeoffset.asm`. Before the fix, zero offset passed while `+150` and `-60` failed; after the fix all cases pass, including midnight wrap for the negative offset and 23:50 plus 20 minutes wrapping to 00:10.
- Added `programs/time.asm` as `TIME.COM`, and wired it into default, shell-test, shell-demo, all-games, and extras images. `scripts/test_shell.py` now runs `time` and checks for `Current time:`.

## 2026-06-07 Post-Alloc Create Failure Handle Leak Probe

- Added `scripts/test_handleleak.py` / `tests/programs/handleleak.asm` for a create failure after `alloc_handle` but before `init_handle_entry`.
- The first run failed on unhandled `INT 21h AH=F0` with `FAIL: HANDLELEAK QUERY BASE`, confirming user space had no way to query the kernel handle count.
- Added test-build `AH=F0h AL=00h` handle-count query behind `TEST_HANDLE_COUNT_QUERY`, returning the number of `H_USED` entries in `AX`.
- Added one-shot `TEST_FLUSH_DIR_SLOT_FAIL` in `flush_dir_slot`; the focused regression sets handle count metadata with `AH=67h`, forces the first create to fail with error 5, verifies the handle count is unchanged, then creates, closes, and reopens a real file.

## 2026-06-07 Norton Commander Program Launch

- Added `scripts/test_norton_commander_launch.py`, which builds NC with `SHELL.COM` and `HELLO.COM`, presses Enter on the selected `HELLO.COM`, and expects the child serial marker.
- Before the fix, the launch probe failed on unhandled `INT 21h AH=0Dh`; with a temporary local disk-reset stub, NC started COMSPEC but the child shell ignored its PSP:80h command tail and stayed interactive at `C:\>hello.com`.
- Implemented `AH=0Dh` as a synchronous-disk no-op and taught `SHELL.COM` to execute `/C <command>` from its PSP command tail once before exiting.
- Focused checks passed: `python3 scripts/test_norton_commander_launch.py`, `python3 scripts/test_norton_commander_smoke.py`, `python3 scripts/test_shell.py`, and `python3 scripts/test_compatapi.py`.
