# Roll Back Directory Extension Failures

## Summary

Directory extension can allocate and link a new cluster before zeroing/writing that cluster. If the write fails, the newly allocated cluster may leak and the FAT chain may remain extended.

## Requirements

- Identify the directory-extension failure paths after `fat_alloc_cluster` and `fat_set`.
- Roll back the FAT link and free the newly allocated cluster if zero/write fails.
- Preserve correct error returns to the caller.

## Acceptance Criteria

- A focused test or fault-injection probe verifies failed directory extension does not leak clusters.
- Existing directory mutation tests still pass.

## Notes

- Reviewers flagged `find_dir_free` subdirectory extension and zero-sector write failure paths.
- This is lower likelihood because it requires disk write failure, but it is a real consistency issue.
