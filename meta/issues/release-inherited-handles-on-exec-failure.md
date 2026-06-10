# Release inherited handle refcounts on EXEC failure

## Summary

`build_psp`'s inherit loop increments `H_REFCOUNT` for every inherited handle (`src/kernel/exec.inc:1341-1372`). The only decrement is `release_inherited_handles`, called from the terminate paths. On EXEC failure after PSP construction — COM path (`load_exec_program` around exec.inc:215-222) and EXE path (`setup_exe_dyn` `.reloc_err_pop`/`.tail_err`, exec.inc:1568-1579, cleanup at `src/kernel/int21.inc:2023-2028`) — memory is freed and `cur_psp` restored, but the increments are never undone. Refcounts on the parent's handles (including std handles 0-4) are permanently inflated, so those slots can never be fully closed or reused.

## Requirements

- On every EXEC failure path after `build_psp`, call `release_inherited_handles` (or an equivalent rollback) against the aborted child PSP before restoring the parent.

## Acceptance Criteria

- Test: force EXEC failures (bad relocation, oversized MINALLOC) repeatedly, then verify the parent can still open/close the full handle table (existing handlecnt-style check); `PASS:` markers.
- Existing spawn/exec/JFT tests pass.
