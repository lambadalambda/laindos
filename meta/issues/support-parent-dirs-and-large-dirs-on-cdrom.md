# Support .. components and large directories on the CD-ROM drive

## Summary

CD path resolution rejects `..`: `cd_parse_next_component` special-cases only `.` (`src/kernel/cdrom.inc:638-648`), and `cd_record_name_to_83` explicitly rejects the ISO9660 self/parent records (cdrom.inc:989-997), so any D: path containing `..` fails with not-found. Separately, directory size checks (`cmp word [cs:cd_dir_size_hi],0 / jne .err` plus `add ax,2047 / jc .err`, cdrom.inc:847-851, duplicated at 1056-1060) reject directories of 0xF801 bytes or more, so large CD directories cannot be scanned.

## Requirements

- Resolve `..` components against the parent directory extent (ISO9660 record index 1).
- Scan directories larger than 62 KiB by iterating extents per sector instead of requiring the full size to fit a 16-bit byte count.

## Acceptance Criteria

- Test ISO with nested directories and one directory >64 KiB: `CD D:\A\B`, `CD ..`, and find-first in the large directory all succeed; `PASS:` markers.
- Existing cd_subdir/cd_find/cd_file tests pass.

## Resolution

`cd_parse_next_component` resolves mid-path `..` via a new `cd_load_parent_dir` that reads the directory's ISO9660 parent record (index 1); textual `CD ..` was already handled by `cur_dir_path_parent`. Trailing `..` in an explicit path remains unsupported (errors cleanly, as before). Both directory scanners now compute the sector count from the full 32-bit directory size, so directories up to 128 MiB scan correctly. `scripts/mkiso.py` gained multi-sector directory support (records padded at sector boundaries per ISO9660) to make the 1500-entry test directory possible.
