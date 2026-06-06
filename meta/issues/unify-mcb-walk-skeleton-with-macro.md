# Unify MCB walk skeleton with macro

## Summary

Five MCB walks in `src/kernel/memory_mcb.inc` (`.amd_walk:23`, `.flfb_walk:88`, `.walk` in `mcb_coalesce_all_free:153`, `.amdh_walk:182`, `.aad_walk:248`) share the same 9-line validate/check/next scaffolding around a varying body. The total duplication is roughly 45 lines.

## Requirements

- Introduce a `mcb_walk_each <body_label>, <next_label>, <done_label>` macro (or a small `mcb_walk_callback` helper) that emits the validate/check/next scaffolding and lets the caller put the body in between.
- Migrate at least three of the five walks to the new form.
- Verify the resulting behavior is identical (focused regression or existing allocator tests).
- Pick the smallest extraction that does not hide the per-walk differences (e.g. first-MCB check, owner-zero check, signature check).

## Acceptance Criteria

- The refactor reduces the per-walk skeleton from 9 lines to a single macro call (plus the body).
- Existing MCB, allocator, and EXEC tests still pass.
- `make test` passes.

## Notes

- Relevant sites: `src/kernel/memory_mcb.inc:23-75, 88-107, 153-169, 182-204, 248-277`.
- `mcb_walk_next` is already a helper; the walk is the natural next layer above it.
- Discovered during a whole-system review on 2026-06-06.
