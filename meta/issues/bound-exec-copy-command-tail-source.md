# Bound exec_copy_command_tail source

## Summary

`exec_copy_command_tail` in `src/kernel/exec.inc` does `mov cx, 128 / rep movsb` from the caller-supplied `[bx+2]`/`[bx+4]` seg:off into `PSP:0x80` without honouring the Pascal length byte at the source or sanity-checking the segment. A parent passing a parameter block with a source segment pointing at kernel memory can leak 128 bytes into the child PSP command tail, where the child then reads it normally. The same family of risk as `validate-exec-env-source-segment`.

## Requirements

- Honour the source length byte (`[bx+1]` for the 2-byte form, or the explicit length when present) when copying the command tail.
- Validate the source segment the same way as the env source segment.
- Clamp the copy length so it never writes past `PSP:0xFF` (the last byte of the reserved area).
- Add focused regression coverage for oversized source, undersized source, and a parent-supplied segment pointing at kernel CS.

## Acceptance Criteria

- A regression passes an EXEC param block with a 200-byte source cmd tail and verifies the child PSP:0x80..0xFF contains only the first 127 bytes plus the canonical `0x0D` terminator.
- The same regression covers a source segment pointing at the kernel CS and verifies EXEC fails cleanly.
- Existing EXEC tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/exec.inc:228-245` (`exec_copy_command_tail`).
- The `mov word [es:0x80], 0x0D00` at line 230 initializes the length+CR but is overwritten by the 128-byte copy immediately after.
- Discovered during a whole-system review on 2026-06-06.
