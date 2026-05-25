# Harden MCB Walks And Memory Top Sizing

## Summary

MCB walks rely on a valid terminating `Z` block and the arena top is hardcoded to `0xA000` despite the kernel reading conventional memory size with `INT 12h`.

## Requirements

- Add bounds or iteration guards to MCB walkers so corrupt chains cannot loop indefinitely or walk past the arena.
- Derive the usable memory top from BIOS conventional memory where feasible.
- Add focused tests for allocator fragmentation and edge cases.

## Acceptance Criteria

- Alloc/free/resize behavior remains compatible with existing tests.
- Corrupt or edge-case MCB chains fail safely in test hooks rather than hanging.
- `make test` passes.
