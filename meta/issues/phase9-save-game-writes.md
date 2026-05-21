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
