# Extract a shared FAT reader for Python scripts

## Summary

Nine scripts reimplement FAT chain readers (~350 duplicated lines) with diverging end-of-chain constants: `scripts/build_extras_hd.py:44-123`, `scripts/test_norton_commander_smoke.py:39-84`, `scripts/test_mi2_save.py:31-90`, plus copies in test_norton_commander_copy.py, test_norton_commander_mkdir_rmdir.py, test_sammax_cd_setmuse_save.py, test_savewrite.py, test_dirmut.py, test_highdir.py. `test_mi2_save.py:45` uses `eoc = 0xFFF0/0xFF0`, wrongly treating reserved values 0xFF0-0xFF6 and bad-cluster 0xFF7 as end-of-chain (silent truncation), while the others use 0xFFF8/0xFF8.

## Requirements

- Create `scripts/fatlib.py` with one BPB parser, FAT12/16 `fat_next`, chain reader, and directory walker; correct EOC constants (>= 0xFF8 / 0xFFF8); migrate all nine scripts.

## Acceptance Criteria

- All migrated tests pass; grep shows no remaining private `fat_next`/`read_chain` definitions in scripts/; the 0xFF0 variant is gone.

## Resolution

Resolved 2026-06-10. scripts/fatlib.py provides FatImage (BPB parse with optional partition offset and FAT-copy index, fat_next, cluster_chain with cycle guard, read_chain, root_dir, find/read_file) plus entry helpers (name83 incl. dot entries, entry_name/attr/cluster/size, iter_dir, find_entry[_offset] accepting dotted names or raw 11-byte forms). Migrated twelve scripts (the nine listed plus test_dirextfail, test_dirextrollback, and test_termflush, which had grown the same copies): build_extras_hd, the four Norton tests, test_mi2_save (killing the wrong 0xFF0 EOC constant), test_sammax_cd_setmuse_save, test_savewrite, test_dirmut, test_highdir. grep shows no private FAT readers left in scripts/. Validated by the full suite, make extras-hd, the Norton battery, and the SETMUSE save smoke (mi2-save still blocked by its separate crash issue).
