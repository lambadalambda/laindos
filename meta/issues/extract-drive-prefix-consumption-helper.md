# Extract drive-prefix consumption helper

## Summary

Seven sites in `src/kernel/path_dir.inc` (lines 652, 790, 935, 1815, 1842, 1859, 1894) repeat the same 6-line `cmp al,'A' / jb / cmp al,'Z' / ja / cmp [bx+1],':' / jne / add bx,2` block to consume a leading `C:`-style drive prefix. The total duplication is roughly 42 lines.

## Resolution

Introduced `STRIP_DRIVE_PREFIX <ptr_reg>` macro in `src/kernel/path_dir.inc:28-38`. All 7 sites migrated to single-line macro calls. 82/82 tests pass.

Commit: 351f2ea

## Follow-up

The same pattern appears in `src/kernel/int21.inc` at lines 2048-2057, 4274-4282, 4354-4363. Moving the macro to a shared include and migrating those 3 sites would eliminate remaining duplication.

## Acceptance Criteria

- The refactor reduces each migrated site from 6 lines to 1 macro call (or 1 helper call).
- Existing path-parsing tests (open, chdir, exec, rename, delete, FindFirst) still pass.
- `make test` passes.

## Notes

- Relevant sites: `src/kernel/path_dir.inc:652, 790, 935, 1815, 1842, 1859, 1894`.
- Discovered during a whole-system review on 2026-06-06.
