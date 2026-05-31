# Fill Memory Documentation Track

## Summary

Expand the interactive documentation with a memory-management track that explains the real-mode layout, MCB arena, allocation strategies, XMS shim, optional EMS support, and the constraints around low memory.

## Requirements

- Replace the current memory placeholder in `docs/site/` with a real track.
- Document the segment layout from boot through relocated kernel, stack, buffers, MCB arena, VGA memory, and optional EMS frame.
- Explain MCB creation, allocation, resizing, freeing, high allocation behavior, owner tracking, and failure paths.
- Explain XMS detection, single-handle backing, block moves, and why EMS is disabled by default.
- Include source excerpts and references to memory-focused tests.

## Acceptance Criteria

- The memory sidebar entry renders a complete walkthrough rather than a placeholder.
- The track documents the constraints that make kernel size and buffer placement risky.
- The track links to relevant tests such as high MCB, allocation strategy, memory failure, XMS, EMS, env MCB, and free memory report tests.
- Local site smoke confirms the track renders without console errors.

## Notes

- This track should be the first stop before changing `src/memory.inc` or low-memory buffers.
- Resolved with `docs/site/page_memory.jsx`, wired into the `mem` route and covered by `make check-docs-sync` source excerpt validation.
