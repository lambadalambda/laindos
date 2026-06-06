# Support DOS compact directory commands and aliases

## Summary

LainDOS supports `CD`, `MD`, and `RD`, but MS-DOS users also expect compact forms and long aliases such as `CD..`, `CD\`, `CHDIR`, `MKDIR`, and `RMDIR`. Today `CD..` and `CD\` are parsed as external commands because the shell only accepts a space or `/` after the built-in name.

## Requirements

- Accept `CD..` as `CD ..`.
- Accept `CD\` as `CD \`.
- Add `CHDIR` as an alias for `CD`.
- Add `MKDIR` as an alias for `MD`.
- Add `RMDIR` as an alias for `RD`.
- Preserve existing `CD [path]`, `MD path`, `RD path`, and drive-switch behavior.

## Acceptance Criteria

- A shell regression runs `MD SHDIR`, `CD\`, `CD..`, `CHDIR SHDIR`, `MKDIR`, and `RMDIR` forms and observes the expected prompt/path changes or directory mutations.
- `CD..` at root does not print `Bad command or file name`.
- Existing shell tests pass.
- `make test` passes.

## Notes

- Current parser: `programs/shell.asm:1301-1321` only treats end-of-string, space, or `/` as a valid built-in delimiter.
- Current command table: `programs/shell.asm:1346-1367` only includes short names.
- MS-DOS 6.22 help documents `CHDIR [drive:][path]`, `CHDIR[..]`, `CD [drive:][path]`, and `CD[..]`; examples include `cd..` and `cd \`.
- Source: `https://www.infania.net/misc/dos622help/cd.html`.
