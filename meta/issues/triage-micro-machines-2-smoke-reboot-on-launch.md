# Triage Micro Machines 2 Smoke Reboot on Launch

## Summary

`make test-mm2-smoke` currently completes the four-disk installer, but launching `MM2` fails to reach DOS/4GW and appears to reboot back to the LainDOS shell.

## Requirements

- Determine whether the reboot is a LainDOS runtime regression, a DOS/4GW/protected-mode compatibility break, or a harness launch artifact after installation.
- Preserve the installer disk-swap coverage while isolating the launch failure.
- Keep Micro Machines 2 vendor media and generated images untracked.

## Acceptance Criteria

- `make test-mm2-smoke` reaches the intended game/copy-protection screen and verifies BIOS tick advancement, or a smaller repro captures the launch/reboot failure.
- The smoke reports a clearer diagnostic when DOS/4GW does not appear after launching `MM2`.
- Any fix keeps the installer swap flow and existing DOS/4GW game smokes passing.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Installer steps passed: disk 2/3/4 swaps and `installer completed`.
- Failure: no game screen within 150 seconds, missing `DOS/4GW Protected Mode Run-time`.
- Serial output showed `C:\MM2>mm2` followed by a fresh `LainDOS booted` banner and shell prompt.
