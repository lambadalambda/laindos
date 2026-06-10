# Fix miscellaneous INT 21h return conventions

## Summary

Small DOS-compatibility deviations found in the 2026-06-10 whole-repo review:

- AH=00h records the caller's arbitrary AL as the return code by sharing `.terminate` with AH=4Ch (`src/kernel/int21.inc:219-220`, 379-383); DOS reports 0.
- AH=3305h "get boot drive" returns the current drive (`mov dl, [cs:dos_drive_num]`, int21.inc:1309-1312), which mutates with AH=0Eh; needs a boot-time constant.
- AH=29h accepts any drive letter A-Z as valid (int21.inc:1075-1082); drives beyond `dos_drive_count` should set AL=0xFF.
- Error-code conflation: all AH=3Fh failures (invalid handle, drive activation, corrupt FAT, sector I/O) funnel into error 6 (int21.inc:3156-3159), and create's `.cr_no_slot` returns 4 for a full directory (2514-2516); callers checking specific codes are misled.
- INT 2Fh answers every unknown function with `xor al,al / iret` (`src/kernel.asm:1666-1693`), falsely advertising support under AL=0-means-installed conventions (e.g. AX=1680h); unknown functions should leave registers untouched.

## Requirements

- Fix each deviation to match RBIL semantics; one topical commit per item is acceptable under this issue.

## Acceptance Criteria

- Test program covering each: AH=00h then AH=4Dh returns 0; boot drive stable across AH=0Eh; AH=29h flags invalid drives; read I/O error vs bad handle return distinct codes; INT 2Fh AX=1680h leaves AL=0x80... unchanged. `PASS:` markers; existing compatapi/versionapi tests pass.
