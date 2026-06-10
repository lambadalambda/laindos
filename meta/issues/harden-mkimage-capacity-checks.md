# Harden mkimage capacity checks

## Summary

Three defects in `scripts/mkimage.py`. (a) Root-directory overflow is unchecked: `add_file_to_root` appends without bound and the writer loops `root_offset += 32` with no comparison against the entry count (mkimage.py:185-194, 361-364) — past 224/512 entries it silently overwrites the FAT-data region (cluster 2 = KERNEL.SYS) producing a corrupt boot image with no error. (b) `Fat12Image.finalize` (mkimage.py:233-246) references `boot_path`, a local of `main()`, so calling it raises NameError; it is dead code duplicating logic `main()` re-inlines at 361-371. (c) Off-by-one in the capacity check (mkimage.py:166-183): after allocating the last valid cluster the "disk image is full" error fires even though the allocation was in-bounds, and the FAT-size bound is never checked at all (fails only by accidental bytearray IndexError).

## Requirements

- Raise a clear error when root entries exceed the format's limit; delete or fix `finalize`; correct the last-cluster check and validate FAT capacity explicitly.

## Acceptance Criteria

- Python-level tests (or assertions exercised by a small script) cover: root overflow raises, last cluster is allocatable, one-past raises; image builds in `make` are byte-identical to before for current content.

## Resolution

Resolved 2026-06-10. (a) add_root_entry guards every root-directory append against ROOT_ENT_CNT and raises "root directory full". (b) The dead finalize method (NameError on main()'s boot_path local) is deleted. (c) Cluster allocation checks the allocated cluster against max_cluster(), which also bounds by FAT capacity (entries derivable from FAT size and bit width), fixing the off-by-one that rejected the last valid cluster. build/disk.img is byte-identical before and after. Covered by the pure-Python scripts/test_mkimage.py.
