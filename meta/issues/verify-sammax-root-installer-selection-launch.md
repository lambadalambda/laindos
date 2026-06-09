# Verify Sam & Max root installer selection launch

## Summary

The Sam & Max CD root installer reaches its text menu under QEMU `-icount shift=6`, but the selected menu action still needs reliable verification after fixing generic EXEC environment inheritance.

## Requirements

- Verify that selecting an installer menu entry launches the configured command instead of only changing directory.
- Keep any Sam & Max coverage vendor-gated and out of the default `make test` ladder.
- Do not seed `C:\SAMNMAX.CD\SETMUSE.INI` or add a Sam & Max-specific kernel workaround.

## Acceptance Criteria

- A manual or automated probe can select `SAM & MAX` from the root installer and observe the configured launch path progressing past the installer menu.
- If automated, the probe records stable screen or serial markers and is wired behind an explicit vendor-gated target.
- Relevant debug notes are updated with the verified result.

## Notes

- The likely generic root cause was fixed by making `INT 21h AX=4B00h` env segment `0` inherit the parent PSP environment instead of generating `COMSPEC` from the current drive.
- A focused multidrive regression now covers that behavior by launching `A:\ENVTEST.COM` while the parent current drive is `C:`.
- QEMU HMP `sendkey` probes can exit the installer with `Esc`, but `ret`/`enter`/`kp_enter` did not trigger the highlighted action in the current scripted setup.
