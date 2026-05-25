# Add FAT Cluster Bounds Checks

## Summary

FAT helpers and cluster walkers assume cluster numbers are valid. Corrupted directory entries or logic bugs can send `fat_next`/`fat_set` outside the valid cluster range.

## Requirements

- Guard `fat_next` and `fat_set` against clusters below 2 and clusters at or beyond `kmax_cluster`.
- Ensure callers receive a safe error/EOC result instead of reading or writing outside the FAT buffer.
- Add a focused regression using a deliberately corrupted image or test hook.

## Acceptance Criteria

- Invalid cluster numbers do not hang or corrupt the FAT.
- Focused regression passes.
- `make test` passes.
