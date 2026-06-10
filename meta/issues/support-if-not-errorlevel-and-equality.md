# Support IF NOT, IF ERRORLEVEL, and IF a==b in the shell

## Summary

`do_if` supports only `IF EXIST` (`programs/shell.asm:1527-1531`); `IF NOT EXIST`, `IF ERRORLEVEL n`, and `IF a==b` lines execute nothing and print no error, so installer batch logic silently takes the fall-through path. The shell already fetches the child exit code via AH=4Dh (shell.asm:2418) only to discard it.

## Requirements

- Implement `IF [NOT] EXIST file`, `IF [NOT] ERRORLEVEL n` (true when last exit code >= n), and `IF [NOT] str1==str2`.
- Store the last child exit code for ERRORLEVEL.
- Unrecognized IF forms should print an error rather than silently doing nothing.

## Acceptance Criteria

- Batch test (extend scripts/test_shell_batch_builtins.py): all three forms with and without NOT branch correctly; ERRORLEVEL reflects a child's AH=4Ch code; `PASS:` markers.
- Existing batch tests pass.

## Notes

- Coordinate with [Report missing batch labels and run bare IF tails](report-missing-batch-labels.md), which changes how the IF tail is dispatched.

## Resolution

Resolved 2026-06-10. do_if now parses an optional NOT prefix (toggling if_negate), then EXIST (AH=43h probe), ERRORLEVEL n (decimal parse compared against last_errorlevel, stored by run_command from AH=4Dh), or str1==str2 (case-sensitive compare). All three share the existing tail dispatch including bare-label GOTO. Malformed forms print "Syntax error". Covered by scripts/test_batchif.py.
