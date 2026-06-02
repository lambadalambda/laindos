# Clarify FAT Flush Error Flag Semantics

## Summary

`flush_fat` returns carry on pending FAT I/O errors but also clears `fat_io_error` before returning. Current callers appear to use carry only, but the flag semantics are ambiguous for future diagnostics.

## Requirements

- Decide whether `fat_io_error` is a latched diagnostic flag or an internal consumed-on-flush flag.
- Preserve current caller behavior for FAT12 and FAT16 writes.
- Add a short implementation note if the flag is intentionally consumed by `flush_fat`.
- Add coverage if the chosen semantics affect observable write or close failures.

## Acceptance Criteria

- The `flush_fat` error path semantics are either documented in code or changed to keep the diagnostic flag until an explicit clear.
- Existing FAT write durability tests pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/fat.inc:275-287`.
- The review found no current caller that inspects `fat_io_error` after `flush_fat`; this is a future-maintenance issue.
