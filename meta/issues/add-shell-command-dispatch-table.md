# Add Shell Command Dispatch Table

## Summary

The shell checks each built-in command through repeated `cmd_match` sequences. A small command dispatch table would make adding and reviewing built-ins less error-prone.

## Requirements

- Replace the repeated built-in command match chain with a compact table of command strings and handler labels.
- Preserve current command matching behavior, including command prefixes and fallback to external command execution.
- Keep the shell binary compatible with current DOS APIs and memory constraints.

## Acceptance Criteria

- Existing shell and AUTOEXEC tests pass.
- Built-ins still work for `EXIT`, `VER`, `DIR`, `CD`, `MD`, `RD`, `TYPE`, `CLS`, `MEM`, `ECHO`, and `REM`.
- `make test` passes.

## Notes

- Review reference: `programs/shell.asm:34` starts the repeated built-in dispatch chain.
