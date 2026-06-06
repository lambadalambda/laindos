# Add MCB_IS_VALID macro

## Summary

Eight sites across `src/kernel/exec.inc:458, 487, 508` and `src/kernel/memory_mcb.inc:25, 90, 155, 184, 250` repeat the same 4-line `cmp byte [ds:0], MCB_SIG_M / je .<ok> / cmp byte [ds:0], MCB_SIG_Z / jne .<skip>` gate to validate a candidate MCB before mutating it. The total duplication is roughly 32 lines.

## Requirements

- Introduce a `MCB_IS_VALID` macro (or a `mcb_validate` helper that sets ZF) so each caller writes `call mcb_validate / jne .<skip>` instead of repeating the two `cmp byte` lines.
- Migrate at least the eight sites to the new form.
- Verify no allocator or EXEC regression.

## Acceptance Criteria

- The refactor reduces each migrated site from 4 lines to 2 lines (macro call plus skip branch).
- Existing MCB, allocator, and EXEC tests still pass.
- `make test` passes.

## Notes

- Relevant sites: `src/kernel/exec.inc:458-461, 487-490, 508-511`, `src/kernel/memory_mcb.inc:25-28, 90-93, 155-158, 184-187, 250-253`.
- Discovered during a whole-system review on 2026-06-06.
