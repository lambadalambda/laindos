# Cover Console Character Edge Semantics

## Summary

Strengthen deterministic `INT 21h` console character API coverage without expanding keyboard timing assumptions.

## Requirements

- Direct console input with no pending key reports empty status and zero character data.
- Character output calls return the character written in `AL`.
- Zero-length buffered line input returns immediately with a zero count.
- Existing echo, direct read, no-echo read, poll, and buffered editing coverage remains intact.

## Acceptance Criteria

- A focused 16-bit console regression exercises the added edge cases under QEMU.
- The regression remains driven by the existing monitor key-injection harness.
- `make test` passes.
- The Phase 19 matrix records the strengthened console coverage.
