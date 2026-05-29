# Strengthen AH=43h Attribute Semantics

## Summary

`INT 21h AX=4301h` currently writes the requested attribute byte directly to the directory entry. Preserve protected directory/volume bits and reject attempts to change them so callers cannot corrupt file or directory entries.

## Requirements

- Allow changing only read-only, hidden, system, and archive attributes through `AX=4301h`.
- Reject requested directory or volume-label bits with access denied.
- Preserve existing directory and volume-label bits on successful attribute changes.
- Keep `AX=4300h` get-attribute behavior and existing register-preservation expectations intact.
- Update the Phase 19 compatibility matrix status for `AH=43h` if behavior changes.

## Acceptance Criteria

- A focused regression covers mutable file attributes, protected-bit rejection, and directory-bit preservation.
- Existing attribute, directory, write/save, high-directory, and register-preservation tests pass.
- `make test` passes.

## Notes

- This follows the Phase 19 compatibility matrix item for strengthening `AH=43h` read-only/hidden/system/archive semantics.
