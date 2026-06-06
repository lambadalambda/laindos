# Add DEL and ERASE built-ins for simple file deletion

## Summary

The LainDOS shell currently has no `DEL` or `ERASE` built-in. MS-DOS users expect those commands for deleting files. The kernel already implements AH=41h delete with guards for directories, read-only files, and open files.

## Requirements

- Add `DEL` and `ERASE` built-ins for deleting a single file path.
- Support `/P` confirmation for the single-file case.
- Print a clear error for missing arguments or delete failures.
- Keep scope limited: no wildcard groups, no `DEL directory` expansion to all files, and no `*.*` whole-directory confirmation in this issue.

## Acceptance Criteria

- A shell regression creates or copies a temporary file, deletes it with `DEL`, and verifies `TYPE` or `DIR` no longer finds it.
- A shell regression repeats the deletion through the `ERASE` alias.
- A shell regression verifies `/P` accepts `Y` and rejects `N`.
- Existing directory mutation and shell tests pass.
- `make test` passes.

## Notes

- Current unsupported list in `docs/site/page_shell.jsx:35-39` names `DEL` as missing.
- Kernel support: `src/kernel/int21.inc:3371` handles AH=41h delete.
- MS-DOS 6.22 help documents `DEL [drive:][path]filename [/P]` and `ERASE [drive:][path]filename [/P]`, with `/P` prompting before deletion.
- Source: `https://www.infania.net/misc/dos622help/del.html`.
