# Guard EXEC Environment Construction

## Summary

`update_exec_environment_path` builds child environment blocks in a fixed `ENV_PARAS` allocation and can write past that block when copying a large caller-provided environment or appending a long executable path tail.

## Requirements

- Bound every write in `src/kernel/exec.inc:update_exec_environment_path` against the allocated environment size.
- Preserve support for caller-provided environment segments and the appended executable-path tail needed by DOS/4GW-style children.
- Fail `EXEC` cleanly with a DOS-compatible error if the requested environment cannot fit.
- Avoid corrupting the following MCB, child PSP, or program image on oversized environments.

## Acceptance Criteria

- A focused EXEC test with an oversized custom environment fails cleanly and leaves memory usable.
- Existing `scripts/test_execenv.py` and `scripts/test_envpath.py` still pass.
- A failed oversized-environment `EXEC` does not change the largest free block except for expected transient allocations that are rolled back.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/exec.inc:275-375`, `src/kernel/exec.inc:390-413`, and `src/memory.inc:10`.
- `docs/debug_log.md:342-346` records why LainDOS copies caller-provided environment variables into a child-owned block and also records the residual fixed-size environment risk.
