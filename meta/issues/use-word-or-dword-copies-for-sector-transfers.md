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
- Before changing each copy loop, identify the weird cases that could break it: odd byte counts, unaligned source or destination offsets, near-64K segment boundaries, partial sectors, zero-length transfers, and direction-flag/register assumptions.
- Add focused regressions for any boundary case not already covered; performance counters alone are not sufficient acceptance evidence.

## Acceptance Criteria

- Existing read/write, overlay, EXEC, CD chunks, and 64 KiB boundary tests pass.
- A generated copy-heavy read/write benchmark or existing read-side benchmark records no regressions.
- Code remains correct for odd byte counts and segment-wrap-limited copies.
- Tests intentionally try to break the optimized copies with odd, unaligned, boundary-adjacent, and partial-sector transfers across file read/write, EXEC/overlay loading, and CD read paths that are modified.
- Review records that an explicit regression-hunting pass was done before accepting the copy-loop optimization.

## Reviewer Focus

- Treat this as high-regression-risk performance work even when the edit looks mechanical. Look for off-by-one tails, copying across a segment boundary, mismatched byte/word counts, unintended 386+ assumptions, and changed flags/registers visible to callers.
- Require a test or a precise existing-test citation for each safety claim. If a reviewer can describe a plausible miscopy, truncation, wrap, or clobber scenario, capture it as a focused regression before accepting the optimization.

## Notes

- This is lower priority than reducing I/O calls, but it is a low-risk cleanup once the affected paths are being edited.
- Prefer mechanical local changes with clear tests over a broad copy-helper rewrite unless repetition becomes a problem.
- Recent performance work produced regressions outside the hot happy paths, so this issue should prioritize adversarial correctness tests before accepting any benchmark improvement.
