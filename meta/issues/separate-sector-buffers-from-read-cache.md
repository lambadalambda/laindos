# Separate Sector Buffers From Read Cache

## Summary

`SEC_BUF` is shared by file read caching, directory scanning, write staging, and executable loading. Prior MI2 save-load corruption came from this class of shared-buffer hazard.

## Requirements

- Separate cache-owned sector data from scratch directory/write buffers, or add a stronger generation/invalidation scheme.
- Keep memory-map constraints explicit with build-time assertions.
- Preserve existing read-cache regression coverage.

## Acceptance Criteria

- Existing `test_readcache.py`, save/load, and file I/O tests pass.
- Buffer ownership is documented or enforced in code.
- `make test` passes.
