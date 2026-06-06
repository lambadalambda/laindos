# Free create-file handle on directory failure

## Summary

`.create_file` in `src/kernel/int21.inc` allocates a handle via `alloc_handle` and writes it to `[cs:cf_handle]` before the directory entry is created or flushed. If `load_dir_slot` or `flush_dir_slot` fails, `.cr_io_err` returns `AX=5` with `CF=1` and never frees the handle, leaking the slot until the process terminates. The same pattern exists in `.create_temp_file`'s `find_in_dir` retry path.

## Requirements

- Free the just-allocated handle if any subsequent directory or FAT write step fails.
- Preserve the existing `AX=5`/`CF=1` error return to the caller.
- Make the cleanup path also restore the previous handle allocation state on a temp-file rename failure.
- Add focused regression coverage that forces a directory write failure and verifies the handle table is unchanged.

## Acceptance Criteria

- A regression forces a directory write failure during `AH=5Bh`/`AH=5Ah` and verifies the handle table matches the pre-call state.
- The same regression covers a temp-file rename failure (`AH=5Ah`) and verifies the same.
- Existing file-create, file-rename, and FAT durability tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:2295-2439` (`.create_file`), including `alloc_handle` at line 2344 and `.cr_io_err` at the end.
- The temp-file retry path in `.create_temp_file` has the same shape and should get the same audit.
- Discovered during a whole-system review on 2026-06-06.
