# Clamp buffered line read for max=1

## Summary

`.read_line_buffered` in `src/kernel/int21.inc` decrements the caller-supplied max-length byte (`mov cl,[si]; dec cl`) without first verifying `cl >= 1` for the dec path, then accepts up to `cl` chars and writes a CR at `[di]`. With caller-passed `max=1`, the count byte is stored as 0 but the CR is still written at `si+2`, leaving consumers that do `mov cl,[si+1]; rep movsb` (e.g. `programs/shell.asm:761-763`) with an inconsistent buffer. Not a kernel-side overflow because the destination is the caller's, but a subtle protocol drift that produces an off-by-one in every consumer that trusts the count byte.

## Requirements

- Reject `max=0` and `max=1` as protocol errors (or normalize `max=1` to "no input possible, CR written at offset 2") so consumers that trust the count byte see a consistent buffer.
- Preserve the current behavior for `max >= 2` (allow `max-1` chars plus CR).
- Add focused regression coverage for `max=0`, `max=1`, `max=2`, and a long input that hits the limit exactly.

## Acceptance Criteria

- A regression calls `AH=0Ah` with `max=1` and verifies the caller's count byte and the CR placement are consistent.
- The same regression covers `max=0` and verifies the caller's buffer is not corrupted.
- Existing console and shell-input tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:412-465` (`.read_line_buffered`), consumer at `programs/shell.asm:761-763`.
- Discovered during a whole-system review on 2026-06-06.
