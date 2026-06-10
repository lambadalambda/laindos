# Support .. components and large directories on the CD-ROM drive

## Summary

CD path resolution rejects `..`: `cd_parse_next_component` special-cases only `.` (`src/kernel/cdrom.inc:638-648`), and `cd_record_name_to_83` explicitly rejects the ISO9660 self/parent records (cdrom.inc:989-997), so any D: path containing `..` fails with not-found. Separately, directory size checks (`cmp word [cs:cd_dir_size_hi],0 / jne .err` plus `add ax,2047 / jc .err`, cdrom.inc:847-851, duplicated at 1056-1060) reject directories of 0xF801 bytes or more, so large CD directories cannot be scanned.

## Requirements

- Resolve `..` components against the parent directory extent (ISO9660 record index 1).
- Scan directories larger than 62 KiB by iterating extents per sector instead of requiring the full size to fit a 16-bit byte count.

## Acceptance Criteria

- Test ISO with nested directories and one directory >64 KiB: `CD D:\A\B`, `CD ..`, and find-first in the large directory all succeed; `PASS:` markers.
- Existing cd_subdir/cd_find/cd_file tests pass.
