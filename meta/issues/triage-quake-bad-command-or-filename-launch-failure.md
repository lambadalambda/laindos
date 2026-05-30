# Triage Quake Bad Command Or Filename Launch Failure

## Summary

Quake reportedly fails to launch with `Bad command or filename`.

## Requirements

- Build or document a local Quake repro image without committing proprietary game files.
- Capture the exact command used, current directory, PATH, and whether the failure occurs from the LainDOS shell, a batch file, or a game launcher.
- Determine whether the target executable name is being resolved incorrectly, whether a parent launcher is spawning another program, or whether the shell is rejecting a valid path.
- Check for command-extension, 8.3 alias, PATH, current-directory, and `COMSPEC` assumptions.
- Add focused shell/EXEC/path regression coverage for any identified failure.

## Acceptance Criteria

- The `Bad command or filename` failure is reproduced and traced to shell/path/EXEC behavior or a separate runtime blocker.
- Quake begins its loader/startup path, or the remaining blocker is documented in a follow-up issue.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: `Quake ("Bad command or filename")`.
- Likely overlaps with the spawn/launcher compatibility issue if the failing command is launched by a parent program.
- Reproduced from `vendor/FreeDOS.VHD` with `C:`, `CD \GAMES\QUAKE`, `QUAKE`.
- The original shell failure was caused by `QUAKE.EXE` being a zero-relocation MZ executable with a nonstandard relocation-table offset; the loader now accepts zero-reloc EXEs without validating an unused relocation table.
- CWSDPMI then required `INT 21h AH=31h` TSR termination and `AH=4Dh` return type `03h`.
- Quake's protected-mode file startup then exposed missing PSP Job File Table metadata; JFT initialization/maintenance now lets Quake `stat` and load `PAK0.PAK`/`PAK1.PAK`.
- Current smoke reaches visible in-game Quake gameplay after acknowledging sound/CD prompts. Subsequent Boom/SMMU compatibility work added narrow `AH=60h` truename and `AX=5D06h` SDA support, so those probes are no longer expected to log as unhandled calls.
