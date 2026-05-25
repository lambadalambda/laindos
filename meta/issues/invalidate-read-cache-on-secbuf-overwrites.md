# Invalidate Read Cache On SEC_BUF Overwrites

## Summary

The recent MI2 load fix invalidates the read cache when `read_sector` reuses `SEC_BUF`, but other code paths can overwrite `SEC_BUF` directly before calling `write_sector`. Those paths can leave `rf_cache_valid` pointing at stale data.

## Requirements

- Identify all code paths that modify `SEC_BUF` without going through `read_sector`.
- Invalidate `rf_cache_valid` before or during any direct `SEC_BUF` overwrite.
- Keep existing `read_file` cache behavior correct after legitimate file-sector reads.

## Acceptance Criteria

- A regression covers reading a cached file sector, performing an operation that directly overwrites `SEC_BUF`, then reading the same file sector again.
- Existing `READCACHE`, save/write, directory mutation, and MI2 save/load checks still pass.

## Notes

- Reviewers specifically flagged `init_dir_cluster`, which zeroes/fills `SEC_BUF` before `write_sector`.
- A broad but simple option is to invalidate the cache in `write_sector`; verify this does not mask other stale-buffer assumptions.
