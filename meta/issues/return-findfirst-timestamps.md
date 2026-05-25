# Return FindFirst Timestamps

## Summary

`store_find_dta` writes zero for DTA file time and date fields, even when directory entries contain valid FAT time/date values.

## Requirements

- Capture directory entry time and date when `find_in_dir` finds a match.
- Store the matched entry's time/date in DTA offsets `+22` and `+24`.
- Preserve existing DTA filename, size, attribute, and continuation fields.

## Acceptance Criteria

- A regression verifies `FindFirst` returns nonzero time/date for a known file and matches the directory entry values.
- Existing directory and shell tests still pass.

## Notes

- Reviewers flagged `src/kernel.asm` `store_find_dta`, which currently writes `0` to both fields.
