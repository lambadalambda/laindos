# Coalesce MCBs After Failed EXEC Rollback

## Summary

Failed `EXEC` paths free transient program and environment MCBs by clearing owners, but do not coalesce adjacent free blocks immediately. Repeated failures can leave the arena fragmented until process termination performs a full coalesce.

## Requirements

- Coalesce or forward-merge adjacent free MCBs after failed `EXEC` rollback paths.
- Preserve successful child termination behavior and existing MCB ownership semantics.
- Keep rollback changes local to failure paths so successful `EXEC` and TSR flows are unaffected.
- Avoid hiding real allocation failures caused by insufficient total memory.

## Acceptance Criteria

- A focused regression repeatedly triggers a failed child load or failed EXE setup and verifies usable free memory is not progressively fragmented.
- Existing EXEC, memory allocator, and shell tests pass.
- `make test` passes.

## Notes

- Relevant rollback paths: `src/kernel/exec.inc:173-178` and `src/kernel/int21.inc:1947-1950`.
- Relevant allocator behavior: `src/kernel/memory_mcb.inc:18-80` and `src/kernel/memory_mcb.inc:148-174`.
- `docs/debug_log.md:193-196` records a previous fragmentation fix for child environment/program/child-owned allocation MCBs after exit; this issue covers the analogous failed-EXEC rollback case.
