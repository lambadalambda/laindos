# Fix IOCTL set-device-info and handle drive reporting

## Summary

Two AH=44h bugs. (a) AL=01h (set device info) is aliased to AL=00h via `.ioctl_set: jmp .ioctl_get` (`src/kernel/int21.inc:3915-3916`): the caller's DX input is discarded and then clobbered with the get-info result; real DOS consumes DX and returns registers unchanged. (b) AL=00h on a file handle reports the current drive (`mov dl, [cs:dos_drive_num]`, int21.inc:3950-3951) instead of the handle's drive, which is available in `H_DRIVE` but SI has already been popped (3945) — a handle opened on B: while A: is current reports drive 0.

## Requirements

- Implement AL=01h as a real set (accept and store the settable bits, or at minimum validate and return success without clobbering DX).
- Report the handle's `H_DRIVE` in the low bits of DX for AL=00h on file handles.

## Acceptance Criteria

- Test: AL=01h preserves DX and returns success; AL=00h on a B: handle while A: is current reports drive 1; `PASS:` markers.
- Existing ioctl/ioctlext tests pass.
