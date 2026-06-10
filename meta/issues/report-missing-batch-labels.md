# Report missing batch labels and run bare IF tails

## Summary

Two related batch-flow problems. (a) `GOTO` to a nonexistent label: `batch_seek_label` (`programs/shell.asm:1611-1648`) scans to EOF and the batch silently ends; MS-DOS prints "Label not found". (b) `if_tail_is_bare_label` (shell.asm:1578-1604) declares any single space-free IF tail a label when `batch_active`, so `IF EXIST FOO.TXT PAUSE` jumps to label `:PAUSE` instead of running `PAUSE` — and a missing label then silently kills the batch. The bare-label behavior is deliberately tested (scripts/test_shell_batch_builtins.py:69) but diverges from MS-DOS, where the IF tail is always executed as a command.

## Requirements

- Print "Label not found" (and stop the batch, matching MS-DOS) when a GOTO/IF-label target does not exist.
- Execute IF tails as commands per MS-DOS; if the bare-label shorthand must be kept for a specific game, gate it narrowly and document why.

## Acceptance Criteria

- Batch tests: `GOTO NOWHERE` prints the error; `IF EXIST FOO.TXT PAUSE`-style tails run the command; update test_shell_batch_builtins.py expectations accordingly; `PASS:` markers.
- DIG demo and Sam & Max batch launch tests still pass (they motivated the current behavior).

## Resolution

Resolved 2026-06-10. batch_seek_label now prints "Label not found" when the scan reaches EOF (the batch then ends at EOF, matching MS-DOS aborting the batch), and do_if executes its tail as a command unconditionally -- if_tail_is_bare_label is gone. The bare-label shorthand existed for DIG.BAT's vendor typo (`if exist C:\LECDEMOS\DIG skipmkdir`, missing GOTO), which on real DOS prints "Bad command or file name" and falls through to harmless mkdirs; the DIG smoke still passes with MS-DOS semantics because the fresh-install path never takes that branch. Covered by the updated ifgoto.bat and the new labmiss.bat in scripts/test_shell_batch_builtins.py.
