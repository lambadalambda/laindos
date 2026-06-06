# Support DIR path/pattern arguments and wide format

## Summary

LainDOS `DIR` currently ignores non-switch operands and always lists `*.*` in the current directory. MS-DOS users expect `DIR [drive:][path][filename]` to list another directory or a matching pattern, and `/W` to show the compact wide layout.

## Requirements

- Parse one non-switch operand for `DIR` as a path or wildcard pattern instead of ignoring it.
- If the operand names a directory, list that directory using an implicit `*.*` pattern.
- If the operand contains a filename or wildcard, pass that path/pattern to FindFirst.
- Support `/W` wide listing with multiple names per row; keep `/P` pagination working.
- Keep the existing long listing as the default.
- Do not implement `/S`, sorting `/O`, attribute filtering `/A`, bare `/B`, lowercase `/L`, or redirection in this issue.

## Acceptance Criteria

- A shell regression verifies `DIR MIDEMO`, `DIR MIDEMO\*.DAT`, and `DIR *.COM` list the expected entries.
- A shell regression verifies `DIR /W` prints entries in a compact multi-column layout and still includes directories visibly.
- Existing shell and FindFirst tests pass.
- `make test` passes.

## Notes

- Current code: `programs/shell.asm:78-104` always uses `dir_pattern: db "*.*", 0`.
- Current argument parser: `programs/shell.asm:106-131` recognizes only `/P` and skips all other tokens.
- MS-DOS 6.22 help documents `DIR [drive:][path][filename] [/P] [/W] ...`, where `[drive:][path]` selects the directory and `[filename]` selects a file or group of files.
- Source: `https://www.infania.net/misc/dos622help/dir.html`.
