# Support Drive-Qualified Relative Paths

## Summary

Treat paths such as `A:FILE.TXT`, `A:*.TXT`, and `A:SUBDIR` as relative to the current directory for that drive instead of as root-qualified paths.

## Requirements

- `AH=3Bh` changes into drive-qualified relative subdirectories from the current directory.
- `AH=3Dh` opens drive-qualified relative files from the current directory.
- `AH=4Eh` searches drive-qualified relative wildcard and exact names from the current directory.
- Existing drive-qualified absolute paths such as `A:\*.COM` keep root-directory behavior.

## Acceptance Criteria

- A focused 16-bit regression exercises open, FindFirst, and CHDIR drive-qualified relative paths under QEMU.
- Existing path, directory, and find regressions still pass.
- `make test` passes.
