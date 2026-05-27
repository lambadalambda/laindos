# Separate Sector Buffers From Read Cache

## Summary

`SEC_BUF` is shared by file read caching, directory scanning, write staging, and executable loading. Prior MI2 save-load corruption came from this class of shared-buffer hazard.

## Requirements

- Separate cache-owned sector data from scratch directory/write buffers, or add a stronger generation/invalidation scheme.
- Keep memory-map constraints explicit with build-time assertions.
- Account for all current `SEC_BUF` users: file read cache, directory scanning, write staging, FAT16 sector caching, and EXEC/overlay header reads.
- Preserve existing read-cache regression coverage.

## Acceptance Criteria

- Existing `test_readcache.py`, save/load, and file I/O tests pass.
- Buffer ownership is documented or enforced in code.
- `make test` passes.

## Notes

- Review references: file read cache uses `SEC_BUF` around `src/kernel.asm:3440`, directory scanning around `src/kernel.asm:5445`, directory writes around `src/kernel.asm:7010`, and loader/header paths also depend on the same buffer.
