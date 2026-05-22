# Phase 8: Built-in INT 33h Mouse Support

## Summary

Implement a minimal built-in DOS mouse service so Monkey Island can detect and use a mouse under LainDOS. Prefer a small in-kernel INT 33h implementation with a PS/2 backend over trying to load CTMouse as a TSR; CTMouse can be used later as a behavioral reference once TSR and multi-program startup support exist.

## Requirements

- Add temporary serial tracing for Monkey Island INT 33h calls before implementing more than the minimum API surface.
- INT 33h AX=0000h reset / installation check reports a mouse installed.
- INT 33h AX=0001h show cursor tracks cursor visibility state.
- INT 33h AX=0002h hide cursor tracks cursor visibility state.
- INT 33h AX=0003h get position and buttons returns current X/Y and button state.
- INT 33h AX=0004h set position updates current X/Y.
- INT 33h AX=0007h set horizontal range clamps current and future X values.
- INT 33h AX=0008h set vertical range clamps current and future Y values.
- Initialize the QEMU PS/2 auxiliary mouse through the i8042 controller and enable packet reporting.
- Decode standard 3-byte PS/2 packets into relative movement and left/right button state.
- Keep all mouse state inside the kernel until TSR support exists.
- Do not copy CTMouse or other GPL mouse-driver code.
- Optional fallback for tests: allow synthetic or keyboard-driven movement only if real PS/2 input is hard to automate.

## Acceptance Criteria

- INT 33h AX=0000h reports mouse installed
- Serial trace documents the INT 33h calls Monkey Island actually makes during startup and interaction.
- Monkey Island detects a mouse instead of falling back to no-mouse behavior.
- Mouse movement in QEMU changes the coordinates returned by INT 33h AX=0003h.
- Left/right mouse button state is visible through INT 33h AX=0003h.
- INT 33h range and set-position calls clamp and update coordinates correctly.
- INT 33h AX=0001h/0002h maintain an internal visibility counter and do not corrupt registers or memory.
- `make test` still passes.
- Monkey Island boots to its title or interaction screen with no mouse-related exceptions or blocking unhandled INT 33h calls.

## Notes

- Current kernel behavior is a stub `INT 33h` handler that returns zeros, so software sees no installed mouse.
- CTMouse is not the first implementation path because it is a TSR-style DOS driver and would require more program-loading, resident-memory, vector-preservation, and hardware support before it helps.
- INT 33h AX=000Ch event callbacks are common in DOS games; add support if the Monkey Island trace shows it is required.
