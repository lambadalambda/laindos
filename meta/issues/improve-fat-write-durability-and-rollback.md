# Improve FAT Write Durability And Rollback

## Summary

Several FAT mutation paths defer flushing until close or later operations. Directory-extension rollback also restores in-memory FAT state without persisting the rollback immediately.

## Requirements

- Review write-extension, close, termination, and directory-extension rollback paths for FAT dirty-state durability.
- Ensure failure paths either persist rollback or leave clearly recoverable in-memory state.
- Add focused regressions for rollback and unclosed-write durability where practical.

## Acceptance Criteria

- Existing save-write, termflush, dirmut, and dirextfail tests pass.
- New or extended tests cover at least one previously unverified FAT dirty-state path.
- `make test` passes.
