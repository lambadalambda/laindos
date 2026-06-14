# Triage Wing Commander Smoke Abnormal Termination

## Summary

`make test-wc-smoke` currently completes the Wing Commander installer, but launching `WC` exits with `Abnormal program termination` before the smoke can answer the Claw Marks quiz.

## Requirements

- Determine whether the failure is a LainDOS runtime regression, a generated-image/install-layout issue, or a harness assumption before quiz detection.
- Preserve the three-disk installer and media-swap coverage.
- Keep Wing Commander vendor media and generated images untracked.

## Acceptance Criteria

- `make test-wc-smoke` reaches the quiz, answers it, and proceeds to the bar-scene verification, or a focused repro captures the abnormal termination.
- The smoke fails earlier and more clearly if `WC` terminates before quiz text can exist in guest RAM.
- Any fix keeps installer-copy verification and existing game smoke coverage intact.

## Notes

- Observed 2026-06-14 at `866b448` with `make -k test-game-smokes`.
- Installer steps passed: disk 2/3 swaps, copied all disks, and completed.
- Serial output showed `C:\WING>wc`, then `Abnormal program termination`.
- Harness symptom after that: `no known quiz question found in guest RAM`.
