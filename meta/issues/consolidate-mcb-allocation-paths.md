# Consolidate MCB allocation and walk paths

## Summary

The free-block split sequence (carve `am_req` paragraphs out of a free MCB, create a new free MCB, fix signatures/sizes) exists in five copies: `alloc_mem_direct` (`src/kernel/memory_mcb.inc:48-65`), `alloc_mem_direct_high` (173-190), the AH=48h handler's `.am_use`/`.am_use_last` (`src/kernel/int21.inc:1370-1386`, 1493-1510), the AH=4Ah grow/shrink paths (1632-1663), and the TSR shrink in `do_terminate_tsr` (`src/kernel.asm:2300-2324`). The AH=48h handler reimplements the whole walk instead of calling the existing allocators, and `do_terminate`'s ownership walk (kernel.asm:2234-2252) plus `tsr_free_owned_extra` (2346-2369) hand-roll the loop the `MCB_WALK_EACH` macro expresses. Several sites also open-code the two compares `MCB_IS_VALID` provides (e.g. kernel.asm:2237-2240, int21.inc:1460-1463).

## Requirements

- Route AH=48h through `alloc_mem_direct`/`alloc_mem_direct_high`; extract one split helper; convert the hand-rolled walks to `MCB_WALK_EACH`; use `MCB_IS_VALID` at the open-coded sites.

## Acceptance Criteria

- Pure refactor: memtest/memreg/memrel/mcbcoex/highmcb/tsr tests and the full ladder pass; one definition of the split sequence remains.

## Notes

- Latent clobber while in the area: `free_exec_environment`/`free_prog_mcb` (`src/kernel/exec.inc:672`, 717) preserve AX/DS but silently destroy SI — give them symmetric save/restore.

## Resolution (2026-06-11)

- One split definition each: `mcb_split_low` (keep the low part, carve
  a free MCB above) and `mcb_split_high` (allocate from the top of the
  block) in memory_mcb.inc, used by alloc_mem_direct,
  alloc_mem_direct_high, the new alloc_mem_direct_best, the AH=4Ah
  grow/shrink paths, and the do_terminate_tsr shrink. The 4Ah shrink's
  hand-rolled single-step forward merge became a mcb_merge_free_forward
  call on the carved tail.
- AH=48h now routes through the shared allocators: mcb_chain_validate
  walks the chain first (preserving the AX=7 corrupt-arena error), the
  strategy dispatch picks alloc_mem_direct / alloc_mem_direct_best /
  alloc_mem_direct_high (keeping the small-allocation last-fit bias),
  and the failure path reuses find_largest_free_block for BX.
- The do_terminate ownership walk and tsr_free_owned_extra use
  MCB_WALK_EACH (the macro moved to memory.inc so kernel.asm sites can
  use it); the AH=49h/4Ah header checks use MCB_IS_VALID.
- free_exec_environment/free_prog_mcb now preserve SI.
- Suite passes 139/139; kernel shrank 38684 -> 38240 bytes.
