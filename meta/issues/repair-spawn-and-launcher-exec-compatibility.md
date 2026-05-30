# Repair Spawn And Launcher EXEC Compatibility

## Summary

External compatibility feedback reports that forking/spawning is missing or broken in practical launcher flows: programs cannot be launched from Norton-style shells, and some games fail with `Bad command or filename` even when a target should be launchable.

## Requirements

- Capture at least one failing launcher or parent-program repro that attempts to spawn a child program.
- Determine whether the failure is in `INT 21h AH=4Bh` EXEC semantics, command-tail/environment handling, current-directory/PATH lookup, `COMSPEC` fallback, file handle inheritance, or shell command dispatch.
- Preserve existing parent/child EXEC regressions while adding coverage for the newly observed launcher behavior.
- Ensure failed spawns return DOS-compatible error codes and preserve parent process state.
- Avoid broad success stubs that hide missing behavior from installers or launchers.

## Acceptance Criteria

- A Norton-style launcher repro or equivalent 16-bit parent program can launch a child COM/EXE under LainDOS.
- At least one reported `Bad command or filename` game-launch failure is fixed or narrowed to a separate documented blocker.
- New focused regression coverage exists for the spawn behavior being fixed.
- `make test` passes.

## Notes

- Reported symptoms: "forking/spawning is not implemented or not working", "can't launch stuff from norton", and some games show `Bad command or filename`.
- Quake and Duke Nukem 3D setup have separate game-specific issues because their symptoms may expose distinct loader/runtime behavior.
