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

- User reported an interactive save attempt produced a working record file, confirming practical game-side file creation/write behavior. Keep the phase open until load behavior is verified and the saved-file format/flow is understood.
- Full VGA Monkey Island boots and runs interactively from `build/monkey_full.img`, but user reported `F5` did not open the save menu. Save/load validation remains open.
