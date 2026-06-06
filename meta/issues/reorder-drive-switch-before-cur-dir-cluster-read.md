# Reorder drive switch before cur_dir_cluster read

## Summary

`.ff_bare_name` in `src/kernel/int21.inc` sets `ff_dir_cluster = cur_dir_cluster` before checking the leading drive letter, then unconditionally adds 2 to `si`. After `validate_path_drive` has switched the active drive, `cur_dir_cluster` happens to be the right value, so the common case (e.g. `"C:FILE.TXT"` with an active drive switch) appears to work. But the same pattern in any future code that calls `.ff_bare_name` after a no-drive activation will silently search the wrong drive. The order is fragile and should be: detect drive, switch if present, *then* read `cur_dir_cluster`.

## Requirements

- Detect the leading drive letter first; switch the active drive if present.
- Read `cur_dir_cluster` (or its post-switch equivalent) only after the drive switch.
- Audit all callers of `.ff_bare_name` and the equivalent in `.ff_path` for the same ordering.
- Add focused regression coverage for `FindFirst` with explicit and implicit drive letters in both bare-name and full-path forms.

## Acceptance Criteria

- A regression calls `FindFirst` with `C:FILE.TXT` while the current drive is `D:` and verifies the search happens on drive `C:`.
- The same regression calls `FindFirst` with `FILE.TXT` (no drive) and verifies the search happens on the current drive.
- Existing FindFirst/FindNext tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:4333-4346` (`.ff_bare_name`), and the equivalent in `.ff_path` if present.
- Discovered during a whole-system review on 2026-06-06.
