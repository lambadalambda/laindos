# LainDOS Test Ladder

LainDOS tests are small, caller-driven compatibility proofs. Add a focused repro before changing a DOS API, hardware shim, loader path, or filesystem behavior.

## Layers

- Tiny DOS programs: NASM programs in `tests/programs/` call one API surface, print `PASS:` or `FAIL:` on serial-visible output, and exit through `INT 21h AH=4Ch`.
- Host runners: Python scripts under `scripts/test_*.py` build a disposable boot image, run QEMU headlessly, and check serial markers with helpers from `scripts/testlib.py`.
- Shell and filesystem runs: broader scripts such as `scripts/test_shell.py`, `scripts/test_savewrite.py`, and `scripts/test_dirmut.py` exercise multiple APIs plus persistent disk-image state.
- Game smokes: scripts such as `scripts/test_shell_monkey.py`, `scripts/test_wolf3d_smoke.py`, `scripts/test_ascendancy_smoke.py`, and `scripts/test_shortline_smoke.py` boot local media, drive QEMU or 86Box through monitor/RPC hooks, and confirm a live framebuffer.

## Commands

- `make test`: build the default image and run the full automated regression ladder from `scripts/run_tests.py`.
- `make check-docs-sync`: verify docs/site source excerpts, documented Makefile targets, local file references, and hardcoded test counts.
- `TEST_JOBS=1 make test` or `make test-serial`: run the default ladder serially when debugging timing or interleaved logs.
- `python3 scripts/test_irqmask.py`: run one focused test directly.
- `python3 scripts/test_sbirq.py`: run the focused Sound Blaster IRQ5 trigger probe with QEMU SB16 hardware.
- `python3 scripts/test_sb16stat.py`: verify SB16 mixer IRQ/DMA register reporting and mixer IRQ-status bits with QEMU SB16 hardware.
- `python3 scripts/test_sb16dma.py`: verify SB16 single-cycle 8-bit, single-cycle 16-bit, and auto-init 8-bit DMA completion IRQs with QEMU SB16 hardware.
- `python3 scripts/test_sbpause.py`: verify the DSP pause/silence command interrupt path with QEMU SB16 hardware.
- `make test-cd-bios`: run the generated-ISO BIOS CD-ROM probe.
- `make test-cd-file`: run the generated-ISO read-only `D:` file API probe.
- `make test-cd-subdir`: run the generated-ISO read-only `D:` subdirectory file API probe, including current-directory CD file attributes and odd unaligned CD reads.
- `make test-cd-find`: run the generated-ISO read-only `D:` directory enumeration probe, including explicit-subdirectory and current-directory wildcard searches.
- `make test-cd-mscdex`: run the generated-ISO MSCDEX detection, drive-list, and device-header probe.
- `make test-cd-exec`: run the generated-ISO `EXEC` and overlay-load probe for COM and EXE programs loaded from `D:`.
- `make test-cd-shellcopy-large`: run the generated CD-to-hard-disk child-shell copy regression that checks large FAT16 writes across FAT-sector boundaries.
- `make test-cd-media-swap`: run the generated-ISO QEMU monitor media-swap regression for CD volume, directory, and file state invalidation.
- `python3 scripts/test_cd_refresh_method.py`: force CD refresh through BIOS fallback after ATAPI failure and verify later file reads use the same method.
- `python3 scripts/test_cd_fetch_di.py`: verify the low-level CD sector fetch helper preserves `DI` even when a test hook clobbers it internally.
- `python3 scripts/test_fat16_flush_fail.py`: inject a FAT16 write-back window flush failure and verify a later retry persists the full file chain.
- `python3 scripts/test_fat16_pending_error_flush.py`: verify a dirty FAT16 window is written before a pending FAT error is reported.
- `python3 scripts/test_boot_chain_bounds.py`: verify corrupt FAT12/FAT16 boot-time kernel chains stop in the boot loader, and that a FAT16 kernel cluster read crossing LBA `65535` reaches the kernel.
- `python3 scripts/test_subdir_cache.py`: verify FAT subdirectory sector cache hit counters, mutation invalidation, drive-switch invalidation, and failed directory-flush cache poisoning guards.
- `make test-cd-86box`: run the generated-ISO read-only `D:` file probe in 86Box with an ATAPI CD-ROM attached as IDE secondary master.
- `make test-installer`: build the self-booting installer/updater floppy, install to a blank QEMU hard disk, verify `A:\INSTALL` refuses to run from a C: boot, then update an existing LainDOS FAT16 image with user data and a high-cluster replacement `KERNEL.SYS`; the updated disk must boot from `C:` after host-side verification.
- `make test-sammax-cd-files`: with local Sam & Max media, extract the cue/bin data track and verify `D:\SAMNMAX` file reads.
- `make test-sammax-cd-install`: with local Sam & Max media, launch root `D:\INSTALL.EXE` under QEMU `-icount shift=6` and verify the CDReader/Bestseller installer screen appears without Borland Pascal `Runtime error 200`.
- `make test-sammax-cd-install-select`: with local Sam & Max media, drive the root installer menu to `Demo: The Dig` and verify the installer-launched shell opens `start.bat`.
- `make test-sammax-cd-start`: with local Sam & Max media, launch `D:\SAMNMAX\SAMNMAX.EXE`, pass the sound-driver prompt, and verify an active framebuffer.
- `make test-sammax-cd-setmuse`: with local Sam & Max media, launch `D:\SAMNMAX\SETMUSE.EXE`, open the sound-card selector, and verify the driver list appears.
- `make test-sammax-cd-setmuse-save`: with local Sam & Max media, boot a writable C: image plus the CD as D:, configure SETMUSE for Sound Blaster 16 port 220, exit/save, and verify `C:\SAMNMAX.CD\SETMUSE.INI` is created.
- `make test-sammax-cd-dig`: with local Sam & Max media, run `D:\DEMOS\DIG\START.BAT`, pass the two batch pauses, and verify IMUSE opens `.\imuse.exe` from the current CD directory and reaches `C:\LECDEMOS\DIG\IMUSE.INI` without the previous sound-engine fatal error.
- `make test-monkey-demo`: smoke-test the shell-launched Monkey Island demo image.
- `make test-game-smokes-qemu`: run the QEMU-backed vendor game smoke ladder when local media is present.
- `make test-game-smokes-86box`: run the 86Box-backed game smoke cross-checks when local media and the headless 86Box harness are present.
- `make test-game-smokes`: run both game smoke groups.
- `make test-shortline-smoke`: run the Shortline-specific smoke with QEMU `-icount shift=6` for its timer calibration.
- `make test-norton-commander`: run the Norton Commander startup, launch, copy, rename/delete, and mkdir/rmdir smokes from the local archive.
- Site docs edits: run `make check-docs-sync`, JSX parsing checks, and a local browser or Playwright smoke when one is available.

## Adding A Focused DOS API Test

1. Write a tiny program in `tests/programs/<name>.asm`.
2. Set `DS` explicitly at startup, normally with `push cs` / `pop ds` for `.COM` tests.
3. Call the exact DOS or BIOS function under test with the smallest state needed.
4. Print a unique `PASS: NAME` marker on success and unique `FAIL: NAME REASON` markers on each failure path.
5. Exit with `AX=4C00h` on success and `AX=4C01h` on failure.
6. Add `scripts/test_<name>.py` using `build_nasm_test_image`, `run_serial_image`, and `check_markers` from `scripts/testlib.py`.
7. Add the script to `DEFAULT_TESTS` in `scripts/run_tests.py` when it is deterministic and fast.
8. Run the focused script first, then `make test`.

Minimal `.COM` shape:

```asm
[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    ; Call the API under test here.

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail:
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db "PASS: EXAMPLE", 13, 10, "$"
fail_msg: db "FAIL: EXAMPLE", 13, 10, "$"
```

Minimal runner shape:

```python
#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "example.img")
KERNEL = os.path.join(BUILDDIR, "example_kernel.bin")


def main():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "EXAMPLE COM", "tests/programs/example.asm", "example.com")
    output = run_serial_image(IMG, timeout=10)
    if not check_markers(output, required=("PASS: EXAMPLE", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nExample test passed.")


if __name__ == "__main__":
    main()
```

## Adding A Game Smoke

1. Keep proprietary archives and extracted files ignored under `vendor/` or generated under `build/`.
2. Build a disposable image from current `src/boot.asm`, `src/kernel.asm`, and `scripts/build_shell_com.py` so the smoke tests the current kernel and shell banner, not a stale image.
3. Use QEMU headlessly with serial captured, monitor sockets for key input, and `screendump` for visual checks.
4. Route audio to QEMU's `none` backend when a game expects SB16 but the test should stay silent.
5. Check for positive serial markers such as `LainDOS booted`, `EXE loaded`, shell prompts, or game banners.
6. Reject negative markers such as `FAIL:`, `EXC `, `INT 21h AH=`, and known game-level fatal exits.
7. Use `framebuffer_active` when serial output alone cannot prove the game reached interactive video.
8. Add a Makefile target only if the smoke depends on local media or non-default emulator pacing; add it to `test-game-smokes-qemu` or `test-game-smokes-86box` only when it is deterministic under that emulator's game-smoke assumptions.

## Debugging And Documentation

- Record non-trivial investigations in `docs/debug_log.md` before switching approaches.
- Keep issue details in `meta/issues/` current while triaging a target.
- Update README or site docs when adding commands, workflows, or test categories.
- When editing `docs/site/`, run `deno check docs/site/*.jsx` plus a browser or Playwright smoke if the local environment has one.
- When editing quoted source excerpts, run `make check-docs-sync` so stale line numbers fail before review.
- Run `git diff --check` before review or commit.
- Before committing non-trivial changes, request the required `code-reviewer-zai` review.

## Representative Tests

- `tests/programs/irqmask.asm` plus `scripts/test_irqmask.py`: focused API/hardware guard regression.
- `tests/programs/execparam.asm` plus `scripts/test_execparam.py`: parent/child `EXEC` parameter coverage.
- `scripts/test_shell.py`: interactive shell, batch, PATH, directory, and command coverage.
- `scripts/test_savewrite.py` and `scripts/test_dirmut.py`: persistent FAT write and mutation checks, including odd unaligned staged write-buffer transfers.
- `scripts/test_cd_shellcopy_large.py`: generated child-shell CD copy replay for large FAT16 writes and GFX-style wildcard copies.
- `scripts/test_fat16_flush_fail.py` and `scripts/test_fat16_pending_error_flush.py`: FAT16 write-back-window error-path regressions that use one-shot kernel test hooks plus host-side FAT chain verification.
- `scripts/test_cd_refresh_method.py` and `scripts/test_cd_fetch_di.py`: CD-ROM fallback and register-preservation regressions using generated ISOs and test-only kernel hooks.
- `scripts/test_subdir_cache.py`: adversarial FAT subdirectory cache regression covering repeated worst-entry lookups, create/delete/rename/attribute/mkdir/rmdir invalidation, drive-switch invalidation, and failed-flush retry behavior.
- `scripts/test_readwrap.py` and `scripts/test_readmulti.py`: handle reads into boundary-sensitive buffers, hard-disk multi-sector reads, and FAT direct-read DMA-boundary coverage.
- `scripts/test_shell_monkey.py`: shell-launched game smoke using QEMU monitor input and a framebuffer check.
