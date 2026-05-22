# Phase 16: Batch Files and AUTOEXEC

## Summary

Add minimal batch-file execution so LainDOS can run startup scripts and simple command sequences.

## Requirements

- Teach the shell to execute `.BAT` files line by line.
- Run `AUTOEXEC.BAT` during shell startup if present.
- Support comments and blank lines.
- Support simple command echoing or `ECHO OFF` if needed by tests.
- Use child return codes once `INT 21h AH=4Dh` is available.

## Acceptance Criteria

- A test image with `AUTOEXEC.BAT` runs commands automatically at boot.
- Batch files can launch programs and built-ins.
- Batch execution returns to the interactive prompt when complete.
- Failing child commands do not crash the shell.

## Notes

- `%VARIABLE%` expansion, `IF`, `GOTO`, and `FOR` can be deferred.
