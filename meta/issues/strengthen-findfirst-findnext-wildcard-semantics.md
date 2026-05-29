# Strengthen FindFirst FindNext Wildcard Semantics

## Summary

Expand focused coverage for `INT 21h AH=4Eh/4Fh` wildcard matching and DTA search state behavior.

## Requirements

- Cover `*.*`, `*.EXT`, `NAME.*`, `?`, and mixed `*`/`?` wildcard patterns.
- Verify `FindNext` advances through all matching entries and returns file-not-found when exhausted.
- Preserve existing DTA search state isolation across multiple active DTAs.
- Update the Phase 19 compatibility matrix status for `AH=4Eh/4Fh`.

## Acceptance Criteria

- The focused `FINDNEXT` regression covers the wildcard cases and exhaustion behavior.
- Existing find attribute, find time, path canonicalization, shell, and filesystem tests still pass.
- `make test` passes.
