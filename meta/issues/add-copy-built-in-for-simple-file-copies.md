# Add COPY built-in for simple file copies

## Summary

The LainDOS shell currently has no `COPY` built-in, even though MS-DOS users expect `COPY source destination` for basic file management. LainDOS already supports the DOS file APIs needed for a simple binary file-to-file copy.

## Requirements

- Add `COPY` as a shell built-in for a single source file and one destination path.
- Copy in binary mode using open/read/create/write/close DOS calls.
- If the destination is an existing directory, create a file with the source basename inside that directory.
- If the destination file already exists, prompt before overwriting unless `/Y` is present.
- Accept `/-Y` as explicit prompt-before-overwrite.
- Print a simple DOS-like completion line such as `1 File(s) copied.` on success.
- Keep scope limited: no wildcard copy groups, no file concatenation with `+`, no `COPY CON`, no device copies, no `/A`, `/B`, or `/V` semantics in this issue.

## Acceptance Criteria

- A shell regression copies `TESTFILE.DAT` to a new filename, types the destination, and verifies the contents match.
- A shell regression copies a file into an existing subdirectory by passing the directory as destination.
- A shell regression verifies overwrite prompting behavior and `/Y` overwrite behavior.
- Existing file API and shell tests pass.
- `make test` passes.

## Notes

- Current unsupported list in `docs/site/page_shell.jsx:35-39` names `COPY` as missing.
- Useful APIs already exist: AH=3Dh open, AH=3Ch create/truncate, AH=3Fh read, AH=40h write, AH=3Eh close.
- MS-DOS 6.22 help documents `COPY [/Y|/-Y] [/A|/B] source ... [destination ...] [/V]`, with simple file copy, overwrite prompting, and directory destination behavior. This issue intentionally implements only the small single-file binary subset.
- Source: `https://www.infania.net/misc/dos622help/copy.html`.
