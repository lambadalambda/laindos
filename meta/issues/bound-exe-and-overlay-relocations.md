# Bound EXE And Overlay Relocations

## Summary

The EXE and overlay loaders trust MZ relocation headers enough to read relocation table entries and patch computed `segment:offset` targets without validating that the relocation table and targets are inside the loaded image or allocated program block.

## Requirements

- Validate MZ header size, relocation table offset, relocation count, and relocation table byte range before applying relocations.
- Reject relocation entries whose target falls outside the valid loaded image or allocated program area required by DOS MZ semantics.
- Apply equivalent checks to normal EXE load, dynamic EXE load, and overlay relocation paths.
- Fail safely with an appropriate EXEC/overlay error instead of corrupting kernel or unrelated program state.

## Acceptance Criteria

- Focused malformed-EXE and malformed-overlay regressions verify out-of-range relocation tables or targets are rejected safely.
- Existing EXEC, overlay, big relocation, shell, and game loader tests pass.
- `make test` passes.

## Notes

- Review references: `src/kernel.asm:7977`, `src/kernel.asm:8041`, and `src/kernel.asm:7624` apply relocation entries.
