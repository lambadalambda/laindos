# Fix Stunt Island Smoke Bad Command Launch

## Summary

`make test-stunt-island-smoke` currently drives the installer and changes to `C:\STUNTISL`, but launching `stunt` returns `Bad command or file name`.

## Requirements

- Determine whether the installer no longer creates the expected executable, the smoke changes into the wrong directory, or the shell command/path handling regressed.
- Keep Stunt Island source media extraction and generated hard-disk images untracked.
- Preserve coverage for the previously fixed post-intro prompt/timer behavior once launch works again.

## Acceptance Criteria

- `make test-stunt-island-smoke` passes to the prompt-class screen and verifies BIOS tick advancement.
- If the installed executable has a different name or location, the builder/smoke documents and uses the correct launch path.
- If the shell cannot find an existing executable in `C:\STUNTISL`, add a focused regression for that lookup behavior.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Serial output showed `C:\>install`, then `C:\STUNTISL>cd \stuntisl`, `C:\STUNTISL>stunt`, `Bad command or file name`.
- This looks more concrete than a framebuffer-threshold failure because the program did not launch.
