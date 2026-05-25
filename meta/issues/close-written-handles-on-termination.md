# Close Written Handles On Termination

## Summary

Programs that write files and terminate without closing handles may leave FAT and directory updates unflushed. DOS normally closes process handles during termination.

## Requirements

- Track enough handle ownership to close or flush handles owned by the terminating PSP.
- On program termination, flush directory entries and FAT changes for owned writable handles.
- Avoid closing parent or kernel-owned handles incorrectly.

## Acceptance Criteria

- A regression writes a file and exits without explicit close; the disk image contains the written file with correct size and FAT chain.
- Existing save/write and EXEC tests still pass.

## Notes

- This is a DOS compatibility gap rather than a confirmed current game blocker.
- It may require adding owner metadata to handle table entries.
