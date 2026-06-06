# Reorder drive switch before cur_dir_cluster read

## Summary

`.ff_bare_name` in `src/kernel/int32h.inc` sets `ff_dir_cluster = cur_dir_cluster` before checking the leading drive letter, then unconditionally adds 2 to `si`. After `validate_path_drive` has switched the active drive, `cur_dir_cluster` happens to be the right value, so the common case (e.g. `"C:FILE.TXT"` with an active drive switch) appears to work. But the same pattern in any future code that calls `.ff_bare_name` after a no-drive activation will silently search the wrong drive. The order is fragile and should be: detect drive, switch if present, *then* read `cur_dir_cluster`.

## Resolution

Closed on 2026-06-06 as a defensive issue with no observable bug in the current code. Investigation showed:

- `.ff_bare_name` is only reached via `.ff_scan_done`'s `je .ff_bare_name` branch, which means the path has no separator.
- Every path to `.ff_bare_name` first passes through `.find_first`'s `call .validate_path_drive`, which calls `activate_drive_for_path`. If the path has a `"X:"` prefix, the active drive is already switched to X before `.ff_bare_name` runs. So `cur_dir_cluster` already reflects the post-switch value.
- Without a `"X:"` prefix, the active drive doesn't change, and `cur_dir_cluster` is still the correct value.
- The reorder is a no-op for the current code path. A TDD test was attempted (`tests/programs/multidrive.asm` with `"C:HDONLY.TXT"` while on A) but passed on both fixed and unfixed code, confirming the reorder doesn't change observable behavior.

The reorder is reasonable defensive coding but not required. Closing as a no-fix-needed until a future caller of `.ff_bare_name` makes the fragility observable.

## Notes

- Relevant code: `src/kernel/int21.inc:4333-4346` (`.ff_bare_name`).
- Original whole-system review entry from 2026-06-06.
