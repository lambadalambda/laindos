# Guard EXE header math against 16-bit overflow

## Summary

Several EXE-header computations lack the overflow checks their siblings have. (a) `exe_min_par` (`src/kernel/exec.inc:88-90`): `sub ax,[0x08] / add ax,[0x0A] / add ax,0x10` with no carry/borrow checks — a huge MINALLOC wraps to a small value, so a program demanding ~1MB launches in a tiny block and scribbles past its MCB instead of failing with error 8; `sub ax,[0x08]` can also underflow when header paragraphs exceed file paragraphs (the `setup_exe_dyn` copy checks this at exec.inc:1463-1465). (b) `load_overlay_direct` computes `ov_skip` with an unchecked shl-4 (exec.inc:746-751) — header >= 0x1000 paragraphs wraps (contrast `setup_exe_dyn:1494-1495` which rejects it) — and the `ov_image_par` rounding (exec.inc:790-796) loses the carry above 0xFFF0, spuriously rejecting ~64K overlays with relocations.

## Requirements

- Mirror the `setup_exe_dyn` guards (`adc dx,0`, header-paragraph bounds, dx-overflow rejection) in `load_exec_program`'s min-par math and in the overlay loader.
- Malformed headers must produce a clean error (8 or 11), never a wrapped allocation.

## Acceptance Criteria

- Tests with crafted EXEs (huge MINALLOC; header paragraphs > file paragraphs; >= 0x1000-paragraph header overlay; ~64K overlay with relocations): first three fail cleanly, the last loads correctly; `PASS:` markers.
- Existing exe/overlay/badreloc tests pass.
