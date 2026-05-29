# Cover AH=29h Parse Filename Semantics

## Summary

Strengthen `INT 21h AH=29h` parse-filename compatibility for FCB-era callers.

## Requirements

- Cover parse control bits for leading separators and preserving existing FCB drive/name/extension fields.
- Cover wildcard return values and `*` expansion into question marks.
- Cover invalid drive-letter reporting.
- Update the Phase 19 compatibility matrix status for `AH=29h`.

## Acceptance Criteria

- A focused 16-bit regression exercises the implemented `AH=29h` behavior under QEMU.
- The regression is part of the default test suite.
- `make test` passes.
- The Phase 19 matrix no longer marks `AH=29h` as missing.
