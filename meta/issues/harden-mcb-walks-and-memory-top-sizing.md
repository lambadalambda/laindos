# Harden MCB Walks And Memory Top Sizing

## Summary

MCB walks rely on a valid terminating `Z` block and the arena top is hardcoded to `0xA000` despite the kernel reading conventional memory size with `INT 12h`.

## Requirements

- Add bounds or iteration guards to MCB walkers so corrupt chains cannot loop indefinitely or walk past the arena.
- Derive the usable memory top from BIOS conventional memory where feasible.
- Reject zero-size, wrapping, or out-of-arena MCB sizes before advancing to the next block.
- Review termination-time and direct-free paths so adjacent free blocks are merged consistently after process exit.
- Add focused tests for allocator fragmentation and edge cases.

## Acceptance Criteria

- Alloc/free/resize behavior remains compatible with existing tests.
- Corrupt or edge-case MCB chains fail safely in test hooks rather than hanging.
- Child process termination leaves reusable free memory in a coalesced state where feasible.
- `make test` passes.

## Notes

- Architecture review references: hardcoded arena sizing starts at `src/kernel.asm:127` and `src/memory.inc:8`; representative MCB walks advance at `src/kernel.asm:1941`, `src/kernel.asm:2000`, and `src/kernel.asm:2054`.
