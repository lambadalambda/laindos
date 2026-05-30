# Triage Micro Machines 2 Hang

## Summary

Micro Machines 2 reportedly hangs under LainDOS.

## Requirements

- Build or document a local Micro Machines 2 repro image without committing proprietary game files.
- Capture serial output, framebuffer state, and exact launch steps.
- Identify whether the hang occurs in an installer/configurator, copy-protection check, loader, or main game runtime.
- Determine whether the blocker is DOS API, file I/O, memory, input, timer, VGA/BIOS, or emulator-specific.
- Add focused regression coverage for any DOS behavior that explains the hang.

## Acceptance Criteria

- The hang has a repeatable repro and recorded failure signature.
- Micro Machines 2 reaches gameplay, or the remaining blocker is isolated into a documented follow-up.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "Micro Machines 2 (hangs)".

## Resolution

- Local media was added as ignored proprietary archive `vendor/003513_micro_machines_2.7z`; it contains four FAT12 floppy images.
- The reproducible local install path is generated-only: extract/merge the floppy contents under `build/mm2_vvfat/`, boot `build/shell_monkey.img` with that host tree attached as `C:` via QEMU `file=fat:rw`, run `C:\CFG>INSTALL E_INST.CFG`, accept the first screen, type `GAMES` at the default `C:\` destination prompt, and press Enter through the disk prompts.
- The install creates `C:\GAMES\MM2` with `MM2.EXE`, `DOS4GW.EXE`, and the expected data directories.
- Launch steps are `C:`, `CD \GAMES\MM2`, `MM2`.
- The reported hang signature is a copy-protection/manual prompt after DOS/4GW starts: `USE CURSOR KEYS TO HIGHLIGHT SYMBOL ON REVERSE OF MANUAL AT LOCATION : COLUMN D ROW 12`.
- No unhandled `INT 21h AH=` or `EXC ` marker appears, the framebuffer is active, and QEMU monitor sampling shows BIOS tick `0x46c` still advancing at the prompt.
- This triage isolates the blocker to the game's manual/copy-protection check rather than LainDOS DOS API, file I/O, memory, input, timer, VGA/BIOS, or emulator behavior. If a valid manual response still fails to reach gameplay, open a new follow-up with that post-check failure signature.
