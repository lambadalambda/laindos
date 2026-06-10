# Enforce attribute and access-mode checks on file open

## Summary

AH=3Dh open performs no attribute checks and mishandles the mode byte. `.of_found` (`src/kernel/int21.inc:2709`) copies cluster/size into the handle without testing `[es:si+11]`, so a directory can be opened (AL=2 yields a writable handle onto the directory's cluster chain; a subsequent write plus close-time `flush_handle_dir_entry` corrupts the directory), and a read-only file opens for write. Additionally the write gate tests the whole mode byte (`cmp byte [cs:si+handles+H_MODE], 0` at int21.inc:3201) instead of the access field, so opens with sharing bits (AL=0x20/0x40 = read access) are granted write access; conversely `.of_cd` (int21.inc:2675-2676) rejects CD opens whose AL carries sharing bits even though access is read.

## Requirements

- Return error 5 when opening an entry with `ATTR_DIR`, or a read-only file with write/read-write access, matching DOS.
- Mask the access field (AND 7) wherever H_MODE gates reads/writes, including the CD open path.

## Acceptance Criteria

- Test program: open subdirectory fails with AX=5; open read-only file with AL=1/2 fails with AX=5; open with AL=0x20/0x40 succeeds for read but AH=40h on it fails with AX=5; open with sharing bits on the CD drive succeeds for read.
- Existing ladder passes.

## Notes

- `create_file` already has the corresponding checks (int21.inc:2422-2425) — mirror them.
