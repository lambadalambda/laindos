# Audit INT 21h Register Preservation

## Summary

Recent compatibility work found game-visible bugs caused by DOS calls clobbering registers that callers expected to survive. Reviewers flagged additional handlers that may still clobber non-return registers.

## Requirements

- Audit implemented `INT 21h` functions for DOS-compatible register preservation.
- Add focused regressions for representative calls, especially open, close, attributes, memory free, and any helper-heavy paths.
- Fix handlers that clobber non-return registers unexpectedly.

## Acceptance Criteria

- Regression programs set sentinel values in `ES`, `SI`, `DI`, `CX`, and `DX`, call target APIs, and verify expected registers survive.
- Simon, Monkey, shell, and memory regression tests still pass.

## Notes

- Reviewers mentioned `AH=3Dh` open, `AH=43h` attributes, `AH=49h` free memory, and `AH=3Eh` close as paths to inspect.
- Treat each confirmed clobber as a topical sub-fix if the audit becomes large.
