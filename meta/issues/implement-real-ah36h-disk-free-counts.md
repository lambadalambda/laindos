# Implement Real AH=36h Disk Free Counts

## Summary

`INT 21h AH=36h` must report free-cluster counts from the active FAT so installers and games see space usage change after file creation and deletion.

## Requirements

- Count free clusters across valid data clusters using the active FAT implementation.
- Preserve DOS-compatible register returns for valid and invalid drive requests.
- Keep FAT12 and FAT16 behavior correct.
- Update the Phase 19 compatibility matrix status for `AH=36h`.

## Acceptance Criteria

- A focused disk-free regression observes free cluster count changes after writing and deleting a file.
- Existing disk-free, write/save, FAT16, and directory mutation tests pass.
- `make test` passes.

## Notes

- This focused issue replaces the stale broad `Fill Missing DOS Compatibility APIs` tracker. Future compatibility work should be tracked through the Phase 19 matrix plus focused implementation issues.
- The existing implementation already walked the FAT; this issue closes by verifying the behavior and extending the regression to cover FAT16 drive numbering.
