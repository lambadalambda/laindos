# Fix INT 33h reset detection and default ratios

## Summary

INT 33h AX=0000 (reset/detect) unconditionally returns AX=0xFFFF / BX=2 (`src/kernel/mouse.inc:48-76`) even when `mouse_init_ps2` failed and `mouse_ps2_enabled` is 0 (mouse.inc:368, `src/kernel.asm:3389`), so programs detect a mouse that does not exist and never receive events. Separately, reset sets both `mouse_ratio_x` and `mouse_ratio_y` to 8 (mouse.inc:68-69); the MS driver default is 8 horizontal / 16 vertical mickeys per 8 pixels, making vertical motion twice standard speed for programs that never call AX=000Fh.

## Requirements

- Return AX=0 from AX=0000 when no PS/2 mouse was initialized.
- Default the vertical ratio to 16 on reset.

## Acceptance Criteria

- Test with PS/2 mouse disabled in QEMU: INT 33h AX=0000 returns AX=0; with mouse present returns AX=0xFFFF and ratio defaults 8/16 (readable via AX=001Bh or observed motion scaling); `PASS:` markers.
- Existing mouse tests pass.
