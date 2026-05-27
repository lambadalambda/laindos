# Unify ASCII Case Conversion And Path Canonicalization

## Summary

The kernel has several independent lowercase-to-uppercase conversions and stores some paths in less canonical form than it uses for lookup. This increases compatibility risk as path handling grows.

## Requirements

- Introduce a single small ASCII uppercase helper or macro and use it from path parsing, FCB parsing, device-name parsing, environment path construction, and related call sites.
- Normalize directory separators and stored current-directory paths consistently.
- Review `.` and `..` behavior, including paths that resolve above root.
- Preserve case-insensitive 8.3 semantics.

## Acceptance Criteria

- Focused path regressions cover lowercase drive/path inputs, mixed separators, `.` and `..` from root and subdirectories, and device-name paths.
- Existing shell, PATH, find-first/find-next, device-name, and directory mutation tests pass.
- `make test` passes.

## Notes

- Review references: lowercase conversion appears at `src/kernel.asm:1709`, `src/kernel.asm:1771`, `src/kernel.asm:5138`, `src/kernel.asm:5317`, `src/kernel.asm:6009`, and `src/kernel.asm:7520`.
