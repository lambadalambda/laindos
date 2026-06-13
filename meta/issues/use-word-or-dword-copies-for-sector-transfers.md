# Use Word or Dword Copies for Sector Transfers

## Summary

Several sector copy paths still use byte copies. Replace safe `rep movsb` loops
with word or 386+ dword copies where alignment and odd-byte tails are handled,
reducing memory-copy overhead in file reads, writes, EXEC loads, and CD reads.

## Requirements

- Identify hot copy loops in file read/write, loader, overlay, and CD read paths.
- Convert copies to `rep movsw` or operand-size-prefixed dword moves only where source, destination, and count handling are safe.
- Preserve odd-length and unaligned partial-sector behavior.
- Keep the 386+ CPU floor documented and respected.

## Acceptance Criteria

- Existing read/write, overlay, EXEC, CD chunks, and 64 KiB boundary tests pass.
- A generated copy-heavy read/write benchmark or existing read-side benchmark records no regressions.
- Code remains correct for odd byte counts and segment-wrap-limited copies.

## Notes

- This is lower priority than reducing I/O calls, but it is a low-risk cleanup once the affected paths are being edited.
- Prefer mechanical local changes with clear tests over a broad copy-helper rewrite unless repetition becomes a problem.
