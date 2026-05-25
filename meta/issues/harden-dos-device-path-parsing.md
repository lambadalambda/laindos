# Harden DOS Device Path Parsing

## Summary

`detect_device_path` unconditionally reads three bytes of a filename before checking whether the path component is long enough.

## Requirements

- Avoid reading past a null terminator for empty, short, or drive-only paths such as `C:` or `A:\`.
- Preserve DOS device-name behavior for `CON`, `NUL`, `AUX`, and `PRN`, including case-insensitive and extension-insensitive matching.
- Keep non-device names such as `NULFILE.DAT` and `CONFIG.SYS` on the normal file path.

## Acceptance Criteria

- Regression coverage includes short non-device paths and longer names beginning with device prefixes.
- Existing device-name regression still passes.
- `make test` passes.
