# Validate 8.3 names on create and rename

## Summary

Created and renamed names are written to disk unvalidated. `parse_83name` converts `*` into literal `?` fill bytes (`src/kernel/path_dir.inc:1750-1783`), and rename (`src/kernel/int21.inc:4669-4677`), mkdir (2271-2273), and create (2464-2466) copy `name_buf` verbatim into the directory entry — so `REN FOO BA*` or creating `A?B` produces entries containing `?` bytes (illegal 8.3 names that self-match later wildcard searches). `name_buf_is_blank` is checked only by mkdir/rmdir, so `REN FOO ..` writes an all-spaces name.

## Requirements

- Reject create/mkdir/rename targets containing wildcard bytes or resolving to a blank name with the appropriate DOS error (rename: error 5/3; create: error 3 or 5 per RBIL).

## Acceptance Criteria

- Test: `REN FOO BA*`, create of `A?B`, and `REN FOO ..` all fail with errors and leave the directory unchanged; `PASS:` markers.
- Existing rename/create/mkdir tests pass.
