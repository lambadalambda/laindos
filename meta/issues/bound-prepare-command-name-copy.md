# Bound the shell prepare_command name copy

## Summary

`prepare_command`'s `.copy` loop (`programs/shell.asm:2281-2304`) copies the command name into the 64-byte `command_name` buffer (shell.asm:3065) terminating only on space or NUL — no bounds check. `line_buf` holds 63 chars, and the no-extension path appends `.COM` plus NUL (2312-2325), so a 63-char extensionless command writes 68 bytes, overflowing into `command_has_ext`, `command_has_path`, and `command_ext_off`; `command_has_ext` becomes `'C'` and `command_ext_is_bat` then dereferences a corrupted pointer. Every other token copier in the file is bounded; this one is not.

## Requirements

- Bound the copy so name + appended extension + NUL always fit `command_name`; overlong names produce "Bad command or file name" instead of corruption.

## Acceptance Criteria

- Test (extend test_shell.py): a 63-char extensionless command prints the error and the shell continues working; `PASS:` markers.
- Existing shell tests pass.

## Resolution

Resolved 2026-06-10. prepare_command's .copy loop now stops storing at command_name+58 and sets a command_too_long flag consumed by run_command, which prints "Bad command or file name". This became more urgent after line_buf grew to 128 bytes for installer command tails. Covered by a 62-char extensionless command probe in scripts/test_shell.py (the deliberate bad-command count is now two).
