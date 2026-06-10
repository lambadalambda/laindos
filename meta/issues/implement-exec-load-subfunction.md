# Implement EXEC AL=1 and DOS child-entry register conventions

## Summary

AH=4Bh rejects AL=1 (load-but-don't-execute) outright (`src/kernel/int21.inc:1986-1991`: only AL=0 and AL=3 are dispatched, else error 1). Debuggers depend on AL=1. Additionally, at child entry DOS sets AL/AH to FCB drive-validity flags, but `exec_exe_dyn` (`src/kernel/exec.inc:1603-1607`) enters with AX = relocated entry CS and `exec_com_dyn` (exec.inc:1636-1644) with AX = PSP segment — programs that test AL at startup misbehave.

## Requirements

- Implement AL=1: load the image, fill the parameter block's SS:SP/CS:IP return fields, do not transfer control.
- Set AL/AH at child entry per the DOS FCB drive-validity convention (0 for valid drives in the default case).

## Acceptance Criteria

- Test: AL=1 load of a known EXE returns the expected SS:SP/CS:IP in the parameter block; spawned child observes AX matching DOS convention; `PASS:` markers.
- Existing exec/spawn tests pass.
