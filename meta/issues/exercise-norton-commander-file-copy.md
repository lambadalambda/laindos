# Exercise Norton Commander file copy

## Summary

Norton Commander can now start under LainDOS and launch a selected child program through COMSPEC. The next compatibility step is proving that NC can mutate the filesystem through its own UI instead of only running external programs.

## Requirements

- Add an automated Norton Commander smoke that drives a simple file copy operation from the NC UI.
- Verify the copied file exists in the resulting disk image with the expected contents.
- Keep the smoke vendor-gated so the default test ladder does not require the Norton Commander archive.

## Acceptance Criteria

- A Norton Commander image with `HELLO.COM` can copy it to `HELLO2.COM` through the NC UI.
- The smoke verifies `HELLO2.COM` exists in the disk image and matches `HELLO.COM`.
- The existing Norton Commander startup and launch smokes still pass.
- Relevant docs/debug notes are updated.

## Notes

- Started on 2026-06-07 after completing the NC child-launch smoke.
- The first implementation of `scripts/test_norton_commander_copy.py` passed without a kernel compatibility change.
