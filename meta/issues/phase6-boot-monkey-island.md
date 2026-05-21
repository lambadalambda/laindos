# Phase 6: Direct Boot into Monkey Island

## Summary

Wire the kernel to directly EXEC C:\MONKEY\MONKEY.EXE with no shell. Implement enough INT 21h for the kernel to launch the game, and log all unimplemented calls.

## Requirements

- Kernel calls dos_exec("\MONKEY\MONKEY.EXE", "") after init
- INT 21h AH=4Bh EXEC (load and execute program)
- INT 21h AH=09h print $-terminated string
- INT 21h AH=25h set interrupt vector
- INT 21h AH=35h get interrupt vector
- INT 21h AH=30h get DOS version (return 3.30 initially)
- INT 21h AH=2Ah get date
- INT 21h AH=2Ch get time
- INT 21h AH=62h get PSP segment
- Unimplemented INT 21h calls logged to serial: INT 21h AH=xx AL=yy AX=zzzz ...
- Ensure INT 20h/22h/23h/24h handlers are properly set up for EXEC (save/restore terminate vectors on program launch)

## Acceptance Criteria

- Kernel boots and attempts to EXEC MONKEY.EXE
- Monkey Island executable is loaded and begins execution
- Unimplemented INT 21h calls appear in serial log with full register dump
- No shell (COMMAND.COM) required
