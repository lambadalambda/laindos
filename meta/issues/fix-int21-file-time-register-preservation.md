# Fix INT 21h File Time Register Preservation

## Summary

`INT 21h AH=57h AL=01h` set file date/time saves caller `CX/DX` as input values, then reuses `CX` and `DX` while computing the handle-table offset. The set-time path should preserve the caller's input registers on return.

## Requirements

- Preserve caller `CX` and `DX` for `AH=57h AL=01h` on success and error paths after handle lookup.
- Preserve existing `AH=57h AL=00h` get file date/time behavior, where `CX/DX` are documented outputs.
- Preserve existing file timestamp update and directory-entry flush behavior.
- Add focused register-preservation coverage for set file date/time.

## Acceptance Criteria

- A regression opens a real file, sets sentinel time/date values in `CX/DX`, calls `AX=5701h`, and verifies `CX/DX` survive on success.
- The regression covers an error path for `AX=5701h` where practical, without checking documented error outputs in `AX`.
- Existing save-write/file-time tests still pass.
- `make test` passes.

## Notes

- Advisor audit identified `src/kernel.asm` around `.file_time` as using `mov cx, HANDLE_SIZE` / `mul cx`, which clobbers `CX/DX` after the set-time inputs were copied to temporary storage.
- This is the same class of bug as the previously found `AH=4Ah` resize register clobber.
