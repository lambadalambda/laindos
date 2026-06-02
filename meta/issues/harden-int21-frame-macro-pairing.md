# Harden INT 21h Frame Macro Pairing

## Summary

`src/kernel/int21.inc` now centralizes many pop frames, but each macro still encodes a hand-named register order. A future handler can silently corrupt the stack by adding a push and selecting the wrong pop macro.

## Requirements

- Audit current INT 21h save/restore frame patterns for mismatches.
- Consider paired push/pop macros or a smaller set of frame conventions that make mismatches easier to spot.
- Preserve caller-visible register behavior and current tests.
- Keep the refactor mechanical and small enough to review.

## Acceptance Criteria

- Register-preservation tests still pass.
- At least the highest-risk or most duplicated INT 21h frame patterns are converted to a safer pairing convention or explicitly documented.
- `make test` passes.

## Notes

- Relevant macros: `src/kernel/int21.inc:1-95`.
- This follows the archived `Deduplicate INT 21h Exit Frames` issue, which reduced duplicated unwind sequences but did not remove frame-order mismatch risk.
