# LainDOS Test Ladder

LainDOS tests are small, caller-driven compatibility proofs. Add a focused repro before changing a DOS API, hardware shim, loader path, or filesystem behavior.

## Layers

- Tiny DOS programs: NASM programs in `tests/programs/` call one API surface, print `PASS:` or `FAIL:` on serial-visible output, and exit through `INT 21h AH=4Ch`.
- Host runners: Python scripts under `scripts/test_*.py` build a disposable boot image, run QEMU headlessly, and check serial markers with helpers from `scripts/testlib.py`.
- Shell and filesystem runs: broader scripts such as `scripts/test_shell.py`, `scripts/test_savewrite.py`, and `scripts/test_dirmut.py` exercise multiple APIs plus persistent disk-image state.
- Game smokes: scripts such as `scripts/test_shell_monkey.py`, `scripts/test_wolf3d_smoke.py`, `scripts/test_ascendancy_smoke.py`, and `scripts/test_shortline_smoke.py` boot local media, drive QEMU through the monitor, and confirm a live framebuffer.

## Commands

- `make test`: build the default image and run the full automated regression ladder from `scripts/run_tests.py`.
- `make check-docs-sync`: verify docs/site source excerpts, documented Makefile targets, local file references, and hardcoded test counts.
- `TEST_JOBS=1 make test` or `make test-serial`: run the default ladder serially when debugging timing or interleaved logs.
- `python3 scripts/test_irqmask.py`: run one focused test directly.
- `make test-monkey-demo`: smoke-test the shell-launched Monkey Island demo image.
- `make test-game-smokes`: run the standard game smoke ladder for Monkey Island, Wolfenstein 3D, and Ascendancy when local media is present.
- `make test-shortline-smoke`: run the Shortline-specific smoke with QEMU `-icount shift=6` for its timer calibration.
- `make test-norton-commander-smoke`: smoke-test Norton Commander from the local archive.
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
2. Build a disposable image from current `src/boot.asm` and `src/kernel.asm` so the smoke tests the current kernel, not a stale image.
3. Use QEMU headlessly with serial captured, monitor sockets for key input, and `screendump` for visual checks.
4. Route audio to QEMU's `none` backend when a game expects SB16 but the test should stay silent.
5. Check for positive serial markers such as `LainDOS booted`, `EXE loaded`, shell prompts, or game banners.
6. Reject negative markers such as `FAIL:`, `EXC `, `INT 21h AH=`, and known game-level fatal exits.
7. Use `framebuffer_active` when serial output alone cannot prove the game reached interactive video.
8. Add a Makefile target only if the smoke depends on local media or non-default QEMU pacing; add it to `test-game-smokes` only when it is deterministic under the standard game-smoke assumptions.

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
- `scripts/test_savewrite.py` and `scripts/test_dirmut.py`: persistent FAT write and mutation checks.
- `scripts/test_shell_monkey.py`: shell-launched game smoke using QEMU monitor input and a framebuffer check.
