# Exercise Norton Commander rename and delete

## Summary

Norton Commander can start, launch a child program, and copy a file under LainDOS. The next filesystem compatibility step is proving NC can rename and delete files through its UI.

## Requirements

- Add an automated Norton Commander smoke that drives a simple rename operation from the NC UI.
- Add a delete step that removes the renamed file through the NC UI.
- Verify the disk image contents after each operation.
- Keep the smoke vendor-gated so the default test ladder does not require the Norton Commander archive.

## Acceptance Criteria

- A Norton Commander image with `HELLO.COM` can rename it to `HELLO3.COM` through the NC UI.
- The smoke verifies `HELLO3.COM` exists and matches the original `HELLO.COM` bytes after the rename.
- The same image can then delete `HELLO3.COM` through the NC UI.
- The smoke verifies `HELLO3.COM` no longer exists after delete.
- Existing Norton Commander startup, launch, and copy smokes still pass.
- Relevant docs/debug notes are updated.

## Notes

- Started on 2026-06-08 after adding the NC copy smoke.
- The first implementation of `scripts/test_norton_commander_rename_delete.py` passed without a kernel compatibility change.
