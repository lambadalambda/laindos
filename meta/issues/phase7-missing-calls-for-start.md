# Phase 7: Implement Missing Calls Until Visible Start

## Summary

Iteratively implement the INT 21h functions that Monkey Island actually calls, as discovered via the serial log, until the game reaches a visible startup/title screen with keyboard working.

## Requirements

- Implement each missing INT 21h function as the game requests it (driven by serial log)
- Likely candidates from the initial API surface:
  - INT 21h AH=43h get/set file attributes
  - INT 21h AH=44h IOCTL (minimal stubs)
- Keyboard input must work (BIOS INT 16h should be left alone)
- Leave BIOS interrupts alone — games call them directly
- Do not implement sound for this phase

## Acceptance Criteria

- Monkey Island reaches a visible startup/title screen in QEMU
- Keyboard input works in the game
- No sound required
- Serial log shows no unhandled INT 21h calls that block startup
