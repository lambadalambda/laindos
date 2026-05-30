# Fill Filesystem Documentation Track

## Summary

Expand the interactive documentation with a FAT filesystem track that explains FAT12/FAT16 image layout, path canonicalization, directory traversal, cluster-chain handling, caching, and write durability.

## Requirements

- Replace the current filesystem placeholder in `docs/site/` with a real track.
- Explain BPB validation, root/data region derivation, FAT12/FAT16 differences, cluster bounds checks, and high-LBA behavior.
- Document 8.3 path parsing, drive-qualified paths, current directory state, and case-insensitive matching.
- Document write paths: create, truncate, delete, rename, directory extension, FAT mirroring, rollback, and cache invalidation.
- Include source excerpts from the filesystem, FAT, path, and disk include files.

## Acceptance Criteria

- The filesystem sidebar entry renders a complete walkthrough rather than a placeholder.
- The track links concepts to existing tests such as FAT16, high directory, bad FAT, save-write, directory mutation, and rollback tests.
- The memory map or diagrams identify the FAT scratch buffer, sector buffer, read cache, and root directory buffer where relevant.
- Local site smoke confirms the track renders without console errors.

## Notes

- Keep license hygiene in mind: summarize behavior, do not copy reference implementation text.
- Resolved with `docs/site/page_filesystem.jsx`, wired into the `fs` route and covered by `make check-docs-sync` source excerpt validation.
