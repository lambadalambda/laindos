# Phase 11: Parent/Child EXEC

## Summary

Implement normal program launching from a parent shell through `INT 21h AH=4Bh AL=00h`.

## Requirements

- Implement `INT 21h AH=4Bh AL=00h` for COM and MZ EXE child execution.
- Build a child PSP with command tail at `PSP:80h`.
- Preserve parent execution state so `INT 20h` and `INT 21h AH=4Ch` return to the parent shell.
- Implement `INT 21h AH=4Dh` to report the child return code.
- Ensure MCB ownership is assigned to the child PSP during execution and released on termination.

## Acceptance Criteria

- The shell can run existing regression programs from disk and return to the prompt.
- A launched COM program receives a DOS-compatible command tail.
- A launched EXE program receives a DOS-compatible PSP and environment pointer.
- The shell can read the child exit status through `AH=4Dh`.
- Regression tests cover shell launch and return for at least one COM and one EXE.

## Notes

- This is the main prerequisite for a useful DOS command shell.
- Keep execution single-tasking; no multitasking or TSR behavior is required.
