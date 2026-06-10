# Treat tab as whitespace in shell parsing

## Summary

Tab (ASCII 9) is not whitespace in the shell's core parsing: `skip_spaces` compares only `' '` (`programs/shell.asm:2863-2870`) and `cmd_match`'s terminator list (2900-2918) omits 9, so a tab-indented batch line or `ECHO<TAB>text` yields "Bad command or file name". Inconsistent with the same file's `do_if` path copier (shell.asm:1541) and `copy_batch_label` (1662), which handle tabs.

## Requirements

- Accept tab wherever space is accepted in command parsing (skip_spaces, cmd_match terminators, token copiers).

## Acceptance Criteria

- Batch test with tab-indented commands and `ECHO<TAB>text` runs correctly; `PASS:` markers.
- Existing shell/batch tests pass.
