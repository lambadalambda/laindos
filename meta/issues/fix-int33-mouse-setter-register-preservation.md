# Fix INT 33h Mouse Setter Register Preservation

## Summary

`INT 33h AX=0004h`, `AX=0007h`, and `AX=0008h` call `mouse_clamp_position`, which uses `AX` as scratch and returns with `AX` clobbered. These mouse setter functions have no documented `AX` output.

## Requirements

- Preserve caller `AX` for mouse set-position, set-horizontal-range, and set-vertical-range calls.
- Keep the existing position/range clamping behavior.
- Add focused INT 33h register-preservation coverage for these setter calls.

## Acceptance Criteria

- A regression calls `INT 33h AX=0004h`, `AX=0007h`, and `AX=0008h`, then verifies `AX` still contains the function number after each call.
- Existing mouse position/range behavior remains covered and passes.
- `make test` passes.

## Notes

- Advisor audits independently identified `src/kernel.asm` call sites for `.set_pos`, `.set_x_range`, and `.set_y_range`; each calls `mouse_clamp_position`, whose scratch `AX` use is not restored before `iret`.
- This is not covered by the archived Phase 8 mouse issue, which focused on functional mouse support rather than register preservation.
