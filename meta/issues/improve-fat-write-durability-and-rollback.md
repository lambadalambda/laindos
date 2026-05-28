# Improve FAT Write Durability And Rollback

## Summary

Several FAT mutation paths defer flushing until close or later operations. Directory-extension rollback also restores in-memory FAT state without persisting the rollback immediately.

## Requirements

- Review write-extension, close, termination, and directory-extension rollback paths for FAT dirty-state durability.
- Ensure failure paths either persist rollback or leave clearly recoverable in-memory state.
- Review FAT copy consistency when one FAT copy write succeeds and a later copy write fails.
- Decide whether boot or mount-time FAT copy mismatch detection is needed for the current compatibility target.
- Add focused regressions for rollback and unclosed-write durability where practical.

## Acceptance Criteria

- Existing save-write, termflush, dirmut, and dirextfail tests pass.
- New or extended tests cover at least one previously unverified FAT dirty-state path.
- `make test` passes.

## Notes

- The review flagged crash or reset windows between FAT copy writes as a future durability risk, especially as FAT16 write-through and FAT12 flush behavior diverge.
- Outcome: directory-extension rollback now flushes the repaired FAT immediately; `test_dirextrollback.py` forces a persisted intermediate extension and verifies rollback reaches all FAT copies.
- FAT copy mismatch detection is deferred for the current compatibility target because LainDOS does not yet have a repair policy for choosing the authoritative copy.
