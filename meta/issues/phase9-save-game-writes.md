# Phase 9: Save-Game Writes

## Summary

Implement file creation, writing, closing, renaming, and date/time functions so that Monkey Island save/load works.

## Requirements

- INT 21h AH=3Ch create file (must work)
- INT 21h AH=40h write file (must work for saves)
- INT 21h AH=56h rename file
- INT 21h AH=57h get/set file date/time
- FAT write support: update FAT entries and flush to disk
- Directory entry creation for new files

## Acceptance Criteria

- Game can save state to disk
- Game can load a previously saved state
- Create/write/close cycle works without corruption
- Rename and date/time functions return correct values
- FAT and directory entries are correctly updated and flushed

## Notes

- Completed after automated save/write coverage and manual Monkey Island 2 save/load confirmation.
- Final closure checks: `make test` passed, and `python3 scripts/test_mi2_save.py` passed with `SAVEGAME.002 created, size=31358`.
- User reported an interactive save attempt produced a working record file, confirming practical game-side file creation/write behavior. Keep the phase open until load behavior is verified and the saved-file format/flow is understood.
- Full VGA Monkey Island boots and runs interactively from `build/monkey_full.img`, but user reported `F5` did not open the save menu. Save/load validation remains open.
- Full Monkey Island 2 save automation now exists in `scripts/test_mi2_save.py`. It reaches the F5 save dialog, enters slot 2 name `auto`, clicks `OK`, then checks the disk image for `C:\MI2\SAVEGAME.002` with an `auto` name prefix.
- `python3 scripts/test_mi2_save.py` now passes after fixing BPB total-sector parsing in `init_bpb_geometry`. The previous failure was a zero-byte write caused by an incorrect `kmax_cluster`, which made FAT allocation report no free clusters even though the image had free space.
- `INT 21h AH=36h` now validates the requested drive, scans FAT entries for actual free clusters in `BX`, returns total clusters in `DX`, and uses the BPB bytes-per-sector value in `CX`. `scripts/test_diskfree.py` covers the initial free-space report, verifies free clusters decrease after a write, and verifies they return after delete.
- Full Monkey Island 2 load failure `Invalid Saved Game (4379, 8224)` was traced to a stale read-sector cache: directory scanning reused `SEC_BUF` during reopen without clearing `rf_cache_valid`, so the save header read could return directory bytes. `read_sector` now invalidates the cache, and `scripts/test_readcache.py` covers the close/reopen/read pattern.
