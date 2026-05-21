# Phase 4: Filesystem Handles

## Summary

Implement DOS file handles and the core file I/O INT 21h functions: open, read, seek, close, FindFirst, FindNext.

## Requirements

- Tiny handle table (at least 20 handles, first 5 reserved for stdin/stdout/stderr/stdaux/stdprn)
- INT 21h AH=3Dh open file
- INT 21h AH=3Eh close file
- INT 21h AH=3Fh read file
- INT 21h AH=42h seek file (from start, current, end)
- INT 21h AH=4Eh find first
- INT 21h AH=4Fh find next
- INT 21h AH=1Ah set DTA
- INT 21h AH=2Fh get DTA
- INT 21h AH=47h get current directory
- INT 21h AH=19h get current drive
- Case-insensitive 8.3 filename matching
- Backslash-separated path parsing
- Current drive and current directory tracking

## Acceptance Criteria

- Test EXE opens, reads, seeks, and closes a file on the disk image (read-only I/O)
- FindFirst/FindNext work for C:\MONKEY\*.*
- Path parsing handles absolute, relative, and bare filenames
- DTA is correctly set and retrieved
