# Cache Subdirectory Sectors for Path Searches

## Summary

Root directories are cached, but subdirectory path resolution and FindFirst-style
searches still reload directory sectors through scratch buffers. Add a small
subdirectory-sector cache to reduce repeated scans in large generated
directories and installer-style workloads.

## Requirements

- Benchmark path lookup and FindFirst/FindNext in generated subdirectories with many entries.
- Cache recently-read subdirectory sectors by drive and LBA.
- Invalidate cached directory sectors on create, delete, rename, mkdir, rmdir, timestamp/metadata updates that rewrite directory sectors, drive switches where applicable, and media changes.
- Preserve root-directory caching behavior and CD-ROM directory semantics.

## Acceptance Criteria

- Generated large-directory benchmark shows fewer physical reads for repeated lookups or scans.
- Directory mutation and rollback tests continue to pass.
- CD parent/large-directory tests and FAT subdirectory tests continue to pass.

## Notes

- Relevant code includes path resolution, directory scan helpers, `flush_dir_slot`, and root/subdir buffer handling.
- Keep the cache small; one or two sectors may be enough to prove value.
