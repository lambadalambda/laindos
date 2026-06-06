# Preserve registers in INT 21h close

## Summary

`.close_file` in `src/kernel/int21.inc` falls through to `.cf_table_handle`, `.cf_inherited_handle`, and `.cf_std_handle` and then `jmp iret_nc` or `jmp iret_cy` without saving a frame. The helper calls clobber BX, DI, and ES. RBIL for `AH=3Eh` requires all registers except AX and CF to be preserved.

## Requirements

- Save and restore BX, DI, and ES across the close-handle helpers.
- Preserve the current carry-flag return path (`iret_nc`/`iret_cy`).
- Keep the existing frame macros (`INT21_POP_FRAME_*`) and pick a matching one for the close path.
- Add focused register-preservation coverage for `AH=3Eh` covering the table-handle, inherited-handle, stdio-handle, and invalid-handle paths.

## Acceptance Criteria

- A regression opens a real file, sets sentinels in BX/DI/ES, calls `AH=3Eh`, and verifies all three survive while CF reflects success.
- The same regression covers at least one error path (invalid handle) and verifies the sentinels still survive.
- `python3 scripts/test_regpres.py` or the relevant focused test passes.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:2668-2718` (`.close_file` and the helper fall-throughs).
- Discovered during a whole-system review on 2026-06-06.
