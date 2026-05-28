# Fill Missing DOS Compatibility APIs

## Summary

Reviews identified missing or skeletal DOS APIs that may affect installers, utilities, or future shell redirection.

## Requirements

- Triage and implement missing high-value INT 21h calls such as `AH=45h`/`AH=46h` handle duplication and `AH=0Ch` flush-and-read.
- Improve edge semantics for drive selection, date reporting, root path handling, and PSP compatibility where needed.
- Write one focused regression per implemented API.

## Acceptance Criteria

- Each new API has a small 16-bit regression program or existing test coverage.
- Compatibility matrix is updated as APIs are implemented.
- `make test` passes.

## Notes

- `INT 21h AH=0Ch` is implemented and covered by `src/flushread.asm` / `scripts/test_flushread.py`.
- `INT 21h AH=45h/46h` is implemented for shared duplicate file handles and covered by `src/duptest.asm` / `scripts/test_dup.py`.
