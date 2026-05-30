# Triage Sokoban Hang

## Summary

Sokoban reportedly hangs under LainDOS.

## Requirements

- Identify the exact Sokoban build/version from the reporter or local game set.
- Build or document a local repro image without committing external game files.
- Capture serial output, framebuffer state, keyboard state, and the last DOS call or CPU location where practical.
- Determine whether the hang is due to console I/O, keyboard input, timer behavior, file I/O, memory, or program loading.
- Add focused regression coverage for any DOS behavior that explains the hang.

## Acceptance Criteria

- The Sokoban hang is reproducible with a documented version and launch path.
- Sokoban reaches interactive gameplay, or the remaining blocker is isolated into a separate issue.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "Sokoban (hangs)".
- Local repro used ignored `vendor/sokoban.zip`, extracted to generated `build/sokoban_files/`, with `SOKOBAN.EXE` direct-booted from a generated `hd10m` image.
- The tested executable prints `SokoBan 95`, `ShareWare Version`, and `Copyright 1995 By Jim Radcliffe`.
- Root cause: Sokoban walks the DOS device-driver chain from `INT 21h AH=52h` list-of-lists data while checking for anti-debug devices. LainDOS exposed the first-MCB word but not the DOS 3.x/4.x resident `NUL` header at `ES:BX+0x22`, so the scan followed unrelated data into bogus far pointers.
- Resolution: `dos_list_of_lists` now includes a `NUL     ` device header with an end-of-chain pointer, and `DOSSTRUCT.COM` covers that structure. The fixed image reaches the interactive puzzle screen.
