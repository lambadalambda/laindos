# Free create-file handle on directory failure

## Summary

`.create_file` in `src/kernel/int21.inc` allocates a handle via `alloc_handle` and writes it to `[cs:cf_handle]` before the directory entry is created or flushed. If `load_dir_slot` or `flush_dir_slot` fails, `.cr_io_err` returns `AX=5` with `CF=1` and never frees the handle, leaking the slot until the process terminates. The same pattern exists in `.create_temp_file`'s `find_in_dir` retry path.

## Resolution

Closed on 2026-06-06 as a non-issue. Investigation showed that `alloc_handle` (in `src/kernel/path_dir.inc:1-26`) only *finds* a free slot by scanning for `H_USED == 0`; it does NOT set `H_USED = 1`. The actual "claim" happens later in `init_handle_entry` (called at the end of `.create_file`'s success path).

So at any `.cr_io_err` failure point after `alloc_handle` returns, the handle slot still has `H_USED = 0`. The next `alloc_handle` call will find the same slot and reuse it. The handle is never "leaked" - it's never claimed in the first place.

A defensive fix was attempted (clearing H_USED/H_OWNER/H_ALIAS on .cr_io_err), but code review by code-reviewer-zai confirmed it's a no-op since the fields are already zero. The TDD test added to verify the fix also turned out to not trigger the bug path: `TEST_DIR_EXT_ZERO_FAIL` fires during `find_dir_extend` (before `alloc_handle` runs), so the failure never reaches `.cr_io_err` and no handle is allocated in the first place.

A real fix would require either (a) making `alloc_handle` atomically claim the slot by setting `H_USED = 1` before returning, or (b) adding a new test hook to force a post-`alloc_handle` failure. Neither was pursued; closing as no-fix-needed.

## Notes

- Relevant code: `src/kernel/int21.inc:2295-2439` (`.create_file`), `src/kernel/path_dir.inc:1-26` (`alloc_handle`).
- Original whole-system review entry from 2026-06-06.
