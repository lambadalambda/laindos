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

- `INT 21h AH=0Ch` is implemented and covered by `tests/programs/flushread.asm` / `scripts/test_flushread.py`.
- `INT 21h AH=45h/46h` is implemented for shared duplicate file handles and covered by `tests/programs/duptest.asm` / `scripts/test_dup.py`.
- `INT 21h AH=68h` is implemented as a file commit operation and covered by `tests/programs/committest.asm` / `scripts/test_commit.py`.
- `INT 21h AH=5Ah/5Bh/67h` compatibility behavior is covered by `tests/programs/createapi.asm` / `scripts/test_createapi.py`; `AH=67h` is a no-op set-handle-count compatibility response and does not expand the fixed handle table.
- `INT 21h AH=33h/54h/2Eh/2Bh/2Dh` compatibility state behavior is covered by `tests/programs/stateapi.asm` / `scripts/test_stateapi.py`.
