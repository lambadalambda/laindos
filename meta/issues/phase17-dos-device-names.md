# Phase 17: DOS Device Names

## Summary

Add standard DOS device names needed by real software and shell redirection.

## Requirements

- Recognize `CON`, `NUL`, `AUX`, and `PRN` as device names where appropriate.
- Support opening and writing `NUL` as a sink.
- Map `CON` to console input/output behavior.
- Return sensible errors for unsupported devices such as `PRN` if no printer exists.
- Keep normal file lookup behavior unchanged for non-device paths.

## Acceptance Criteria

- Programs can open and write `NUL` successfully.
- `TYPE file > NUL` or equivalent future shell behavior can discard output.
- `CON` reads and writes through console APIs.
- Device names are recognized case-insensitively and independent of extension padding.

## Notes

- `NUL` is the highest-value first device because DOS software commonly opens it.
