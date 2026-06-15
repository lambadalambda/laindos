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
- Before optimizing, design adversarial regressions that try to make the cache go stale or return the wrong directory sector; promote any probe that exposes a real cache bug into the automated suite.
- Include negative/error-path coverage for failed mutations, rollback paths, media changes, drive switches, and CD/FAT boundary cases where stale cached data would be dangerous.

## Acceptance Criteria

- Generated large-directory benchmark shows fewer physical reads for repeated lookups or scans.
- Directory mutation and rollback tests continue to pass.
- CD parent/large-directory tests and FAT subdirectory tests continue to pass.
- New or extended tests prove the cache is invalidated after every mutation path listed above, and that a failed read or failed mutation cannot leave a valid-looking stale cache entry.
- Review records that an explicit regression-hunting pass was done before accepting the cache optimization.

## Reviewer Focus

- Treat this as high-regression-risk performance work: look for stale cache state, missed invalidations, rollback/error-path leaks, register preservation drift, and assumptions that only hold for root directories or generated happy-path tests.
- Require concrete test evidence for every invalidation claim. If a reviewer can describe a plausible way to break the cache, capture it as a focused regression before accepting the optimization.

## Notes

- Relevant code includes path resolution, directory scan helpers, `flush_dir_slot`, and root/subdir buffer handling.
- Keep the cache small; one or two sectors may be enough to prove value.
- Recent performance work produced regressions in cache lifetime and error paths, so this issue should bias toward smaller changes with deliberately adversarial tests over benchmark-only validation.
