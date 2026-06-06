# Extract drive-prefix consumption helper

## Summary

Seven sites in `src/kernel/path_dir.inc` (lines 652, 790, 935, 1815, 1842, 1859, 1894) repeat the same 6-line `cmp al,'A' / jb / cmp al,'Z' / ja / cmp [bx+1],':' / jne / add bx,2` block to consume a leading `C:`-style drive prefix. The total duplication is roughly 42 lines.

## Requirements

- Introduce a `STRIP_DRIVE_PREFIX <ptr_reg>` macro that takes `bx` or `si` as an argument and emits the 6 lines, with the local skip label.
- Or introduce a real helper `consume_drive_prefix` that takes a register by value and returns the post-prefix value in the same register.
- Migrate at least the seven sites to the new form.
- Verify no path-parsing regression.

## Acceptance Criteria

- The refactor reduces each migrated site from 6 lines to 1 macro call (or 1 helper call).
- Existing path-parsing tests (open, chdir, exec, rename, delete, FindFirst) still pass.
- `make test` passes.

## Notes

- Relevant sites: `src/kernel/path_dir.inc:652, 790, 935, 1815, 1842, 1859, 1894`.
- Discovered during a whole-system review on 2026-06-06.
