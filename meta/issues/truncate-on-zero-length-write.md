# Truncate or extend the file on AH=40h with CX=0

## Summary

AH=40h with CX=0 must set the file size to the current position (truncate or extend), per RBIL. `.wf_file_loop` starts with `cmp word [cs:wf_count], 0 / je .wf_file_done` (`src/kernel/int21.inc:3305-3307`), returning AX=0 success having done nothing. The extend direction happens to work via the gap-fill at `.wf_gap_start` (3203-3219), but truncation (position < size: shrink the size and free tail clusters) is entirely missing.

## Requirements

- On CX=0: set H_SIZE to the current position, free clusters beyond the new size, update the directory entry on flush, and keep the gap-fill behavior for extension.

## Acceptance Criteria

- Test: write 1024 bytes, seek to 100, AH=40h CX=0, close; file size is 100 and the freed clusters are reusable (verified via AH=36h free count or by filling the disk); extension via seek-past-EOF + CX=0 still works; `PASS:` markers.
- Existing write/seek tests pass.
