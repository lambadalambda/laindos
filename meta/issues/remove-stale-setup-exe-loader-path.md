# Remove Stale setup_exe Loader Path

## Summary

`setup_exe` is an old static EXE setup path that appears unreachable now that initial and child loads use `setup_exe_dyn`. If reused, it would read and copy from `TEMP_SEG` using stale assumptions that do not match the current full-file load path.

## Requirements

- Confirm `setup_exe` has no callers.
- Remove the dead routine or replace it with a tiny wrapper that cannot diverge from `setup_exe_dyn`.
- Preserve the dynamic COM and MZ EXE loader paths.
- Keep documentation/source excerpts in sync if line-referenced site pages mention the loader path.

## Acceptance Criteria

- No references to `setup_exe` remain except possibly documentation notes about historical removal.
- Initial boot into `KERNEL.SYS` still reaches the shell/game target.
- Existing EXE relocation and EXEC tests pass.
- `make test` passes.

## Notes

- Stale code removed: `setup_exe` and `exec_exe` in `src/kernel/exec.inc`. See commit history for the original line numbers (the file shrank by 90 lines after removal).
- Current initial EXE path calls `setup_exe_dyn` at `src/kernel.asm:363`.
- Current child EXEC path calls `setup_exe_dyn` at `src/kernel/int21.inc:1945`.
