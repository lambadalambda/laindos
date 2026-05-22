# Phase 10: Minimal Command Shell

## Summary

Add a tiny command shell that runs as a normal DOS program and provides the first interactive command loop for LainDOS.

## Requirements

- Build a shell program as `SHELL.COM` or `COMMAND.COM`.
- Boot the shell as the default program for a dedicated shell image or build target.
- Provide a prompt and line input.
- Implement initial built-ins: `DIR`, `CD`, `TYPE`, `CLS`, `VER`, `MEM`, and `EXIT`.
- Keep shell behavior simple and compatible with the current single-tasking kernel model.

## Acceptance Criteria

- A QEMU boot reaches the shell prompt.
- Built-in commands print useful output and return to the prompt.
- `DIR` lists root directory entries from a FAT12 image.
- `CD` changes the current directory using existing DOS APIs.
- `TYPE` prints a text file through DOS file APIs.
- `EXIT` terminates the shell cleanly.

## Notes

- The shell should be a normal DOS program, not kernel code.
- Prefer using `INT 21h` services from the shell so missing DOS APIs become visible.
