# Restore INT 22h/23h/24h vectors on process exit

## Summary

`build_psp` saves the live INT 22h/23h/24h vectors into PSP offsets 0x0A-0x15 (`src/kernel/exec.inc:1310-1321`), but neither `do_terminate` (`src/kernel.asm:2217`) nor `do_terminate_tsr` (kernel.asm:2276) restores them; the IVT entries are written exactly once at boot (kernel.asm:1506-1511). Any program that hooks INT 23h/24h via AH=25h leaves the vector pointing into freed memory after exit. The kernel itself executes `int 0x24` from `sector_io_loop` (`src/kernel/disk.inc:58`), so the next disk error after such a program exits jumps into garbage.

## Requirements

- On AH=4Ch / INT 20h / AH=00h termination, restore IVT 22h/23h/24h from the terminating PSP before returning to the parent.
- AH=31h (TSR) must restore 23h/24h the same way while keeping the resident image.

## Acceptance Criteria

- Test program: child hooks INT 24h (and 23h) via AH=25h, exits; parent reads the vectors via AH=35h and verifies they match the pre-EXEC values; prints `PASS:` markers.
- Existing ladder passes.
