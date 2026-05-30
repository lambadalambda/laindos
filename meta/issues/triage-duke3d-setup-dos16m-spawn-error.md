# Triage Duke Nukem 3D SETUP DOS/16M Spawn Error

## Summary

Duke Nukem 3D's `SETUP.EXE` reportedly fails with a DOS/16M spawn-related error and a corrupted-looking filename.

## Requirements

- Build or document a local Duke Nukem 3D setup repro image without committing proprietary game files.
- Capture the exact error text, serial output, current directory, environment, and files present when `SETUP.EXE` runs.
- Determine whether DOS/16M is failing to open a child executable, temporary file, overlay, configuration file, or command processor.
- Investigate whether the random-character filename indicates DTA/path-buffer corruption, environment/command-tail corruption, handle inheritance, or unsupported spawn semantics.
- Add focused regression coverage for the identified DOS/16M expectation where feasible.

## Acceptance Criteria

- The `DOS/16M Error: [8] cannot open file '{random characters}' Spawn Error: Error 0` failure is reproduced and traced to a specific compatibility gap.
- `SETUP.EXE` reaches its configuration UI, or the remaining blocker is isolated into a documented follow-up.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: `Duke Nukem 3D's SETUP.EXE ("DOS/16M Error: [8] cannot open file '{random characters}' Spawn Error: Error 0")`.
- This may overlap with the spawn/launcher compatibility issue, but the random-character filename suggests there may also be a path or memory-corruption angle.
