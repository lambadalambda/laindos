# Centralize Handle Initialization And Device Metadata

## Summary

File create, file open, and device open initialize handle-table entries in separate duplicated sequences. Device handles are also identified by overloading `H_DIR_LBA=0`.

## Requirements

- Centralize common handle initialization so new fields are initialized consistently.
- Evaluate replacing the `H_DIR_LBA=0` device sentinel with an explicit device flag or documented magic value.
- Preserve current close/read/write/IOCTL behavior.

## Acceptance Criteria

- Existing file, device, termination-flush, and register-preservation tests pass.
- Handle initialization has one common base path or macro.
- `make test` passes.
