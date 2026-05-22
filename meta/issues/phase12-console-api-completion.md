# Phase 12: Console API Completion

## Summary

Fill in the DOS console functions needed by a shell, common utilities, and simple interactive programs.

## Requirements

- Implement `INT 21h AH=01h` read character with echo.
- Implement `INT 21h AH=02h` write character.
- Implement `INT 21h AH=06h` direct console I/O.
- Implement `INT 21h AH=07h` direct character input without echo.
- Implement `INT 21h AH=0Ah` buffered line input.
- Keep `AH=08h`, `AH=09h`, and `AH=0Bh` behavior compatible with the new functions.

## Acceptance Criteria

- Automated tests verify each implemented console function.
- The shell can use DOS buffered input instead of BIOS-only input.
- Console output works through DOS APIs rather than direct serial-only helper code.
- Existing Monkey and MI2 compatibility does not regress.

## Notes

- Ctrl-C and Ctrl-Break behavior can be deferred unless a test program needs it.
