# Allow Norton Commander to launch programs

## Summary

Norton Commander reaches its external launch path under LainDOS, but launching a selected program does not currently start the child. The probe with `HELLO.COM` found two compatibility gaps: NC calls `INT 21h AH=0Dh` before launching, and it relies on the `COMSPEC` shell honoring a command tail such as `/C HELLO.COM`.

## Requirements

- Implement the minimal DOS disk-reset compatibility needed for NC's launch path.
- Teach `SHELL.COM` to handle COMMAND.COM-style `/C <command>` command tails and terminate after running the command.
- Add an automated Norton Commander launch smoke that proves NC can start a child program.

## Acceptance Criteria

- A Norton Commander image with `HELLO.COM` and `SHELL.COM` can launch `HELLO.COM` by pressing Enter on the selected file.
- The smoke observes `PASS: HELLO.COM` from the launched child.
- Existing shell/API tests still pass.
- Relevant docs/debug notes are updated.

## Notes

- Discovered on 2026-06-07 while checking whether the Norton Commander smoke was enough to prove external program launch.
- The initial probe failed with unhandled `INT 21h AH=0Dh`; after a temporary local stub, NC started `SHELL.COM` through `COMSPEC` but the shell ignored the command tail and stayed interactive.
- Completed on 2026-06-07 with `AH=0Dh` disk-reset compatibility, `SHELL.COM` `/C <command>` PSP-tail execution, and `scripts/test_norton_commander_launch.py` proving NC can launch `HELLO.COM`.
