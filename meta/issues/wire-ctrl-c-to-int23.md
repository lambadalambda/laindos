# Generate INT 23h on Ctrl-C

## Summary

Ctrl-C/Ctrl-Break are never acted on: `console_read_char`/`console_input_status` pass 0x03 through as ordinary data (`src/kernel/console.inc:39-86`), INT 23h is installed as a bare `iret` (`src/kernel.asm:1640-1641`), and `break_flag` (AH=33h, `src/kernel/int21.inc:1302-1308`) is stored but never consulted. Programs relying on ^C to abort console reads cannot.

## Requirements

- On ^C during the console input functions (AH=01h/07h/08h/0Ah and CON handle reads), echo `^C`, and invoke INT 23h; default INT 23h behavior terminates the program.
- Honor `break_flag` for the extended-check semantics (check on every INT 21h call when set).

## Acceptance Criteria

- Test: child program loops on AH=01h; injected ^C (QEMU sendkey) terminates it and the parent observes the termination; with a custom INT 23h that returns carry-clear, execution continues; `PASS:` markers.
- Existing console/keyboard tests pass.
