# Document INT 21h IF-On-Return Compatibility

## Summary

LainDOS intentionally returns from most `INT 21h` paths with `IF=1` via `iret_nc`, `iret_cy`, `iret_nc_zf`, and `iret_nc_nz`. A review flagged this as surprising flag behavior. Follow-up source and runtime checks confirm it is not MS-DOS 4.00 return-flag fidelity, but it is an explicit Stunt Island compatibility shim.

## Requirements

- Document that `INT 21h` DOS returns currently force interrupts enabled as a compatibility behavior.
- Record the Stunt Island rationale near the implementation or in the architecture/debug documentation.
- Record that real MS-DOS 4.00 enables interrupts while running DOS code but preserves the caller's saved IF on `IRET`.
- Keep the existing `FindFirst` regression that verifies `IF` is set on a successful DOS return when the caller entered with interrupts disabled.
- Do not remove the behavior without a Stunt Island retest or an equivalent compatibility decision.

## Acceptance Criteria

- Documentation points future maintainers to the Stunt Island `IF=0` timer-deadlock investigation.
- `python3 scripts/test_findedge.py` still verifies the intended `FindFirst` return behavior.
- Any code comment added near `src/kernel.asm:383-412` is concise and explains why `IFLAG` is ORed into the return frame.
- `make test` passes if implementation or tests change.

## Notes

- Relevant implementation: `src/kernel.asm:383-412`.
- `docs/debug_log.md:222-224` records the stuck Stunt Island loop, the `IF=0` state before `INT 21h AH=4Eh`, and the decision to make DOS-style `INT 21h` returns set `IF`.
- `docs/debug_log.md:234` records the `test_findedge.py` regression.
- `docs/debug_log.md` also records the 2026-06-01 follow-up: MS-DOS 4.00 `DISP.ASM` uses `STI` after switching to a DOS stack and `CLI` before `IRET`, while a local MS-DOS 4 probe returned `IF=0` after caller `CLI` for both `AH=30h` and successful `AH=4Eh`.
