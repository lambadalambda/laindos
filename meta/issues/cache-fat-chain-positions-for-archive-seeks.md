# Cache FAT Chain Positions for Archive Seeks

## Summary

Large archive/resource files often receive many seeks and small reads. The
current handle state caches the last cluster position, but backward or scattered
seeks can still require walking the FAT chain from the beginning. Add a small
per-handle or shared cluster-position cache for archive-style seeks.

## Requirements

- Benchmark random and repeated seeks inside a generated large FAT file.
- Count FAT chain-walk steps separately from physical sector reads.
- Add a small bounded cache mapping file cluster indexes to actual cluster numbers.
- Invalidate or repair cache state on writes, truncates, close, delete, rename, and FAT chain mutation.

## Acceptance Criteria

- Generated random/archive seek benchmark shows substantially fewer FAT chain-walk steps.
- Sequential reads remain at least as fast as before.
- Existing FAT mutation, truncate, delete/rename, and save/write regressions pass.

## Notes

- Keep memory cost small; do not store full chains for large files.
- Useful patterns include direct-mapped or tiny LRU caches with 8 to 16 entries.
