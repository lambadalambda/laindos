# Support standard handles in read and seek

## Summary

AH=3Fh has no standard-handle path: `.read_file` (`src/kernel/int21.inc:2896-2914`) goes straight to `resolve_handle_for_use`, which requires `H_USED=1`; the handle table is statically zeroed and `alloc_handle` starts at slot 5, so `AH=3Fh BX=0` (read stdin) fails with error 6. AH=42h seek (int21.inc:3522-3529) fails the same way. Every sibling handler (write, close, ioctl, dup, commit) special-cases BX<5 — read and seek are the omissions.

## Requirements

- AH=3Fh on handles 0-4 reads from the console device (line-buffered semantics per the CON read behavior, see [Buffer CON device handle reads](buffer-con-handle-reads.md)).
- AH=42h on handles 0-4 returns the DOS device behavior (offset 0, no error) rather than error 6.
- Prefer folding the std-handle check into `resolve_handle_for_use` so the ~9 duplicated per-handler checks collapse (int21.inc:2791, 3164, 3920, 3967, 4041, 4116, 4157, 4219, 4746).

## Acceptance Criteria

- Test program reads keyboard input via `AH=3Fh BX=0` and seeks handle 0 without error; prints `PASS:` markers.
- Existing ladder passes.
