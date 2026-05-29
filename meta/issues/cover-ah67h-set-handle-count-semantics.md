# Cover AH=67h Set Handle Count Semantics

## Summary

Strengthen `INT 21h AH=67h` set-handle-count compatibility around low-count requests and LainDOS's fixed handle-table limit.

## Requirements

- Treat requests below 20 handles as accepting the DOS minimum rather than failing.
- Preserve compatibility success for larger defensive handle-count requests.
- Document that LainDOS still caps effective dynamic file handles at the fixed 20-entry table.
- Update the Phase 19 compatibility matrix status for `AH=67h`.

## Acceptance Criteria

- A focused 16-bit regression exercises the implemented `AH=67h` behavior under QEMU.
- The regression is part of the default test suite.
- `make test` passes.
- The Phase 19 matrix no longer marks `AH=67h` as a stub.
