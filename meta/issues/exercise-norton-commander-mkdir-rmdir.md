# Exercise Norton Commander mkdir and rmdir

## Summary

Norton Commander can start, launch, copy, rename, and delete files under LainDOS. The next filesystem compatibility step is proving NC can create and remove directories through its UI.

## Requirements

- Add an automated Norton Commander smoke that drives directory creation from the NC UI.
- Add a removal step that deletes the created empty directory through the NC UI.
- Verify the disk image contents after each operation, including directory metadata for the created directory.
- Keep the smoke vendor-gated so the default test ladder does not require the Norton Commander archive.

## Acceptance Criteria

- A Norton Commander image can create `AAADIR` through the NC UI.
- The smoke verifies `AAADIR` exists as a directory and contains valid `.` and `..` entries.
- The same image can then remove `AAADIR` through the NC UI.
- The smoke verifies `AAADIR` no longer exists after removal.
- Existing Norton Commander startup, launch, copy, and rename/delete smokes still pass.
- Relevant docs/debug notes are updated.

## Notes

- Started on 2026-06-08 after adding the NC rename/delete smoke.
- `AAADIR` is used instead of `TESTDIR` so the directory sorts first in NC's default panel ordering before the removal step.
- The first mkdir run passed; the rmdir keyboard flow needed three Tabs to reach NC's `Delete` button and a second Enter for the final confirmation.
