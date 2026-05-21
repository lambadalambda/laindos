# Phase 8: Mouse Shim

## Summary

Implement a minimal INT 33h mouse driver shim so Monkey Island can see and use a mouse.

## Requirements

- INT 33h AX=0000h reset / installation check
- INT 33h AX=0001h show cursor
- INT 33h AX=0002h hide cursor
- INT 33h AX=0003h get position and buttons
- INT 33h AX=0004h set position
- INT 33h AX=0007h set horizontal range
- INT 33h AX=0008h set vertical range
- Initially, keyboard arrows can be mapped to fake mouse movement

## Acceptance Criteria

- INT 33h AX=0000h reports mouse installed
- Game sees a mouse pointer
- Mouse position and button state work well enough for game interaction
- Cursor visibility show/hide work
