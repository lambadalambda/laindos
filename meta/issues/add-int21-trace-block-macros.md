# Add INT21 trace-block macros

## Summary

15 gated trace sites in `src/kernel/int21.inc` (lines 478, 734, 818, 1219, 1358, 1503, 1677, 1719, 2537, 2613, 2641, 2671, 2965, 3440, 3753) plus the unconditional unhandled-AH trace at lines 276-296 repeat the same fixed prologue `cmp word [cs:trace_left], 0 / je .X_no_trace / dec word [cs:trace_left] / pusha / push ds / push cs / pop ds` (7 lines) and the same fixed epilogue `pop ds / popa` (2 lines) wrapping a `mov si, msg_trace_<name> / call serial_print` body that varies. The result is roughly 135 duplicated lines.

## Requirements

- Introduce a `TRACE_BEGIN <name>` / `TRACE_END` macro pair (or a `TRACE_POINT <name>` single-call form) that emits the gate + pusha/ds/cs/pop-ds prologue and the `pop ds / popa / serial_print crlf` epilogue.
- Migrate at least the 15 gated sites to the new macros without changing the visible trace output.
- Verify the unconditional unhandled-AH trace is also covered by the same macro form.
- Run the full test ladder and verify the trace output is unchanged.

## Acceptance Criteria

- A `scripts/test_trace.py` or equivalent runs with `INT21_TRACE=1` and verifies each handler emits the same trace line as before the refactor.
- The refactor reduces the trace block at each migrated site from ~9 fixed lines to 2 macro calls.
- Existing INT 21h tests still pass.
- `make test` passes.

## Notes

- Relevant sites: `src/kernel/int21.inc:478, 734, 818, 1219, 1358, 1503, 1677, 1719, 2537, 2613, 2641, 2671, 2965, 3440, 3753`.
- The unconditional unhandled-AH trace is at `src/kernel/int21.inc:276-296`.
- Discovered during a whole-system review on 2026-06-06; this is a refactor / DRY opportunity, not a correctness fix.
