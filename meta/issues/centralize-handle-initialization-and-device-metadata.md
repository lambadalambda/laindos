# Centralize Handle Initialization And Device Metadata

## Summary

File create, file open, and device open initialize handle-table entries in separate duplicated sequences. Device handles are also identified by overloading `H_DIR_LBA=0`.

## Requirements

- Centralize common handle initialization so new fields are initialized consistently.
- Evaluate replacing the `H_DIR_LBA=0` device sentinel with an explicit device flag or documented magic value.
- Ensure create, open, device, close, and termination-close paths initialize and clear the same handle fields consistently.
- Preserve current close/read/write/IOCTL behavior.

## Acceptance Criteria

- Existing file, device, termination-flush, and register-preservation tests pass.
- Handle initialization has one common base path or macro.
- `make test` passes.

## Notes

- Review references: create initializes fields at `src/kernel.asm:3024`, open at `src/kernel.asm:3154`, and device handles at `src/kernel.asm:5029`.
- Outcome: common handle setup is centralized in `init_handle_entry`; device handles keep the existing `H_DIR_LBA=0` / `H_DIR_OFF=DEV_*` sentinel to avoid growing the handle table.
