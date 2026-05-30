# Triage Shortlines Hang

## Summary

Shortlines reportedly hangs under LainDOS.

## Requirements

- Identify the exact Shortlines build/version from the reporter or local game set.
- Build or document a local repro image without committing external game files.
- Capture serial output, framebuffer state, and the exact point where the hang occurs.
- Determine whether the hang is due to DOS API, file I/O, memory, input, timer, VGA/BIOS, or emulator-specific behavior.
- Add focused regression coverage for any DOS behavior that explains the hang.

## Acceptance Criteria

- The Shortlines hang is reproducible with a documented version and launch path.
- Shortlines reaches interactive gameplay, or the remaining blocker is isolated into a separate issue.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "Shortlines (hangs)".
- Local repro uses ignored `vendor/SHRTLINE.zip`, extracted to generated `build/shortline_files/`, with `SL.EXE` direct-booted from a generated `hd10m` image.
- The tested executable is `SHRTLINE/SL.EXE`, 148661 bytes, SHA1 `bed66d3f194bc17d7ab15d033b401bc33fd695fd`, and the game screen identifies itself as `SHORTLINE`, game by Andrei Snegov, DOKA 1992 Moscow, version 1.1.
- Root cause of the hard crash: Shortline temporarily restores `INT 09h` from an uninitialized zero vector while setting up private timer/keyboard handlers. QEMU can deliver IRQ1 in that window, causing execution at `0000:000B`. LainDOS now masks PIC IRQ1 while `INT 09h` is `0000:0000` and restores the prior mask when a non-null keyboard vector is installed or the program terminates.
- Remaining default-QEMU behavior: after the IRQ1 guard, Shortline exits through `Divide by 0 exit` because its PIT/`INT 08h` calibration observes zero elapsed private timer ticks under normal unthrottled QEMU. This is isolated as emulator pacing; `make test-shortline-smoke` runs the game with QEMU `-icount shift=6` and reaches interactive gameplay.
- Regression coverage: `IRQMASK.COM` covers the null-`INT 09h` mask/restore behavior, and `scripts/test_shortline_smoke.py` covers the local Shortline gameplay path without committing proprietary media.
