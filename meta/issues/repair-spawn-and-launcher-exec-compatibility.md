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

## Resolution

- Added an equivalent 16-bit launcher repro: `SPAWN.COM` opens `SPAWNDAT.TXT`, `EXEC`s `SPAWNCH.COM`, and verifies the child can see and use the inherited handle.
- Fixed `build_psp` so EXEC children inherit the parent's fixed 20-entry PSP Job File Table instead of always receiving `0,1,2,3,4,FF...`, and so inherited handles keep the parent handle usable after a child-local close.
- The regression failed before the fix with `FAIL: SPAWNCH JFT` and passes after the PSP JFT copy.
- Added `make test-norton-commander-smoke` for `vendor/003064_norton_commander.7z`; it reaches the Norton Commander 5.5 UI with no unhandled DOS call trace.
- Verification passed with the focused EXEC/JFT ladder, `make test` (`75/75`), `make test-norton-commander-smoke`, and `make test-game-smokes`.
- The earlier reported `Bad command or filename` game launch failure is covered by the archived Quake triage, and the Duke SETUP spawn failure is covered by the archived Duke triage and `EXECENV` regression.
- The Norton Commander archive was moved from `build/` to `vendor/` during this work; the archive itself remains untracked proprietary/local media.

## Notes

- Reported symptoms: "forking/spawning is not implemented or not working", "can't launch stuff from norton", and some games show `Bad command or filename`.
- Quake and Duke Nukem 3D setup have separate game-specific issues because their symptoms may expose distinct loader/runtime behavior.
- Duke Nukem 3D setup exposed one concrete spawn gap: child EXEC with a caller-provided environment segment still needs a child executable-path tail. `EXECENV` now covers copying caller-provided variables into a child-owned environment with the launched path tail.
