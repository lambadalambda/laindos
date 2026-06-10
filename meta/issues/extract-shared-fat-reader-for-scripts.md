# Extract a shared FAT reader for Python scripts

## Summary

Nine scripts reimplement FAT chain readers (~350 duplicated lines) with diverging end-of-chain constants: `scripts/build_extras_hd.py:44-123`, `scripts/test_norton_commander_smoke.py:39-84`, `scripts/test_mi2_save.py:31-90`, plus copies in test_norton_commander_copy.py, test_norton_commander_mkdir_rmdir.py, test_sammax_cd_setmuse_save.py, test_savewrite.py, test_dirmut.py, test_highdir.py. `test_mi2_save.py:45` uses `eoc = 0xFFF0/0xFF0`, wrongly treating reserved values 0xFF0-0xFF6 and bad-cluster 0xFF7 as end-of-chain (silent truncation), while the others use 0xFFF8/0xFF8.

## Requirements

- Create `scripts/fatlib.py` with one BPB parser, FAT12/16 `fat_next`, chain reader, and directory walker; correct EOC constants (>= 0xFF8 / 0xFFF8); migrate all nine scripts.

## Acceptance Criteria

- All migrated tests pass; grep shows no remaining private `fat_next`/`read_chain` definitions in scripts/; the 0xFF0 variant is gone.
