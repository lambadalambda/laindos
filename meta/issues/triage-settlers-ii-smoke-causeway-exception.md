# Triage Settlers II Smoke CauseWay Exception

## Summary

`make test-settlers2-smoke` currently installs Settlers II Gold from the CD data track, but launching the installed game hits a CauseWay exception and DOS/4GW fatal error before the menu smoke can pass.

## Requirements

- Determine whether the CauseWay exception is caused by a LainDOS protected-mode/runtime regression, a CD/data-path issue, or an existing QEMU limitation that the smoke should detect differently.
- Preserve the CD installer coverage and the installed-image reboot check.
- Keep Settlers II vendor media and generated CD/hard-disk images untracked.

## Acceptance Criteria

- `make test-settlers2-smoke` reaches the 640x480 menu screen and verifies BIOS tick advancement, or a focused repro captures the CauseWay/DOS4GW launch failure.
- The smoke distinguishes the expected launcher fallback from unexpected CauseWay exception output.
- Any fix keeps focused CD-ROM, ATAPI, and DOS/4GW smokes passing.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Installer steps passed: drive/default-path selection, copy finished, reboot returned to the shell.
- Launch output included `CauseWay DOS Extender v3.14`, `Exception: 0D, Error code: F000`, and `DOS/4GW fatal error (1313): can't resolve external references`.
- Failure: `no menu screen within 120s; last stats: (2, 18317)`.
