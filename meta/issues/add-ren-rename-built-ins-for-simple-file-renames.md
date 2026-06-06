# Add REN and RENAME built-ins for simple file renames

## Summary

The LainDOS shell currently has no `REN` or `RENAME` built-in. MS-DOS users expect these commands for changing file names. The kernel already implements AH=56h rename with read-only/open-handle guards.

## Requirements

- Add `REN` and `RENAME` built-ins for a single source file and destination filename.
- Require exactly two operands.
- Reject destination operands that include a drive or directory path, matching MS-DOS `REN` behavior.
- Use AH=56h for the actual rename.
- Print a clear error for missing arguments, invalid destination path, or rename failures.
- Keep scope limited: no wildcard rename patterns in this issue.

## Acceptance Criteria

- A shell regression renames a file with `REN OLD.TXT NEW.TXT` and verifies the old name is gone and the new name exists.
- A shell regression repeats the path through the `RENAME` alias.
- A shell regression verifies `REN OLD.TXT SUBDIR\NEW.TXT` is rejected rather than moving the file.
- Existing rename API and shell tests pass.
- `make test` passes.

## Notes

- Current unsupported list in `docs/site/page_shell.jsx:35-39` names `REN` as missing.
- Kernel support: `src/kernel/int21.inc:4441` handles AH=56h rename.
- MS-DOS 6.22 help documents `RENAME [drive:][path]filename1 filename2` / `REN ...`, and explicitly says the second filename cannot specify a new drive or path; use `MOVE` for moving files or directories.
- Source: `https://www.infania.net/misc/dos622help/rename.html`.
