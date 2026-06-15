# Fix Stunt Island Smoke Bad Command Launch

## Summary

`make test-stunt-island-smoke` regressed after hard-disk write-cache work. The initial symptom was `Bad command or file name`; after the Normality FAT-chain flush fix, the installer completed and `stunt` launched, but the game stayed on a black screen because installed game files were corrupted.

## Requirements

- Determine whether the installer no longer creates the expected executable, the smoke changes into the wrong directory, or the shell command/path handling regressed.
- Keep Stunt Island source media extraction and generated hard-disk images untracked.
- Preserve coverage for the previously fixed post-intro prompt/timer behavior once launch works again.

## Acceptance Criteria

- [x] `make test-stunt-island-smoke` passes to the prompt-class screen and verifies BIOS tick advancement.
- [x] The installed executable path is still `C:\STUNTISL\STUNT.EXE`; no smoke path change was needed.
- [x] The root cause was write-cache lifetime across non-write INT 21h calls, not shell lookup, so no shell lookup regression was added.

## Resolution

- `INT21_STI` flushes dirty staged hard-disk data before dispatching non-`AH=40h` INT 21h calls and invalidates the clean staged sector. Same-sector adjacent writes still coalesce across repeated `AH=40h` calls.
- `INT21_STI` preserves `AX` around that entry flush so function subselectors such as `AH=42h AL=0` survive the helper's active-drive comparison.
- A no-snapshot Stunt install now matches the known-good installed `STUNTISL` tree byte-for-byte (`diff_count 0`).

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Serial output showed `C:\>install`, then `C:\STUNTISL>cd \stuntisl`, `C:\STUNTISL>stunt`, `Bad command or file name`.
- This looks more concrete than a framebuffer-threshold failure because the program did not launch.
- On 2026-06-15, `2b1f440` advanced the symptom to install plus launch plus black screen. Comparing no-snapshot installs against a known-good `549c360` image showed `24` installed files differed, while immediate post-write flushing made the installed tree match exactly.
- Final verification: `make test-stunt-island-smoke`, `make bench-disk-write`, `make test-normality-install`, and `make test-cd-shellcopy-large` pass.
