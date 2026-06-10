# Send EOI before invoking the mouse user callback

## Summary

`irq12_handler` calls the user INT 33h callback before acknowledging the interrupt: `mouse_ps2_byte` → `.packet` → `mouse_invoke_callback` → `call far [cs:mouse_callback_off]` (`src/kernel/mouse.inc:597`) all run before `.eoi` (mouse.inc:624-626). The user callback therefore executes with IRQ12 in-service at both PICs and IF=0, blocking the timer (IRQ0) and keyboard for its whole duration — long game callbacks lose ticks and keystrokes.

## Requirements

- Issue EOI to both PICs (and optionally STI) before invoking the user callback; ensure the handler is not re-entered for the same packet (re-entry guard already exists per the archived guard-mouse-callback-re-entry issue — verify it still holds with the new ordering).

## Acceptance Criteria

- Test: mouse callback that busy-waits while sampling the BIOS tick count confirms ticks advance during the callback; existing mousecb/mouseratio tests pass.
