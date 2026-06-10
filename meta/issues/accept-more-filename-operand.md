# Accept a filename operand in MORE

## Summary

`MORE FOO.TXT` is a silent no-op: `parse_more_scan` sets `more_has_file` only after a `'<'` (`programs/shell.asm:1867-1871`); a bare filename operand is skipped character by character, and `do_more` (shell.asm:1755-1763) returns without output or error when `more_has_file=0`. Real MORE accepts a filename argument.

## Requirements

- Treat a bare operand as the input file (equivalent to `MORE < FILE`); print an error for a missing file instead of silence.

## Acceptance Criteria

- Shell test: `MORE FOO.TXT` pages the file; `MORE MISSING.TXT` prints an error; `PASS:` markers.
- Existing shell tests pass.

## Resolution

Resolved 2026-06-10. parse_more_scan treats the first bare token as the input file (same as `MORE < FILE`); a missing file reports the existing "File not found" open error. Covered in scripts/test_shell.py (more testfile.dat / more missing.txt).
