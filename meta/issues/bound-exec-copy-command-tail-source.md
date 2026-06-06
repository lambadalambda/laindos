# Bound exec_copy_command_tail source

## Summary

`exec_copy_command_tail` in `src/kernel/exec.inc` does `mov cx, 128 / rep movsb` from the caller-supplied `[bx+2]`/`[bx+4]` seg:off into `PSP:0x80` without honouring the Pascal length byte at the source or sanity-checking the segment. A parent passing a parameter block with a source segment pointing at kernel memory can leak 128 bytes into the child PSP command tail, where the child then reads it normally. The same family of risk as `validate-exec-env-source-segment`.

## Requirements

- Honour the source length byte (`[bx+1]` for the 2-byte form, or the explicit length when present) when copying the command tail.
- Validate the source segment the same way as the env source segment.
- Clamp the copy length so it never writes past `PSP:0xFF` (the last byte of the reserved area).
- Add focused regression coverage for oversized source, undersized source, and a parent-supplied segment pointing at kernel CS.

## Resolution

`exec_copy_command_tail` now validates the source tail segment, reads the Pascal length byte, clamps to the PSP-safe maximum of 126 command bytes, copies only those bytes to `PSP:0x81`, and writes a canonical `0x0D` terminator at `PSP:0x81+len`. Invalid source segments return `AX=8` with carry set; the COM path frees the partially built program/env blocks directly, while the EXE setup path returns the failure to the existing cleanup caller.

The regression test failed before the fix with `FAIL: TAILCHK LEAK`, then passed after the fix. It covers an empty source tail followed by sentinel bytes, a 200-byte source tail clamped to 126 bytes plus CR at `PSP:0xFF`, and a source segment of `0x0340` rejected as a kernel segment.

Commit: 04d1e51

Verification: `python3 scripts/test_exectail.py`, `make`, `make check-docs-sync`, and `make test` (`83/83` passed).

## Acceptance Criteria

- A regression passes an EXEC param block with a 200-byte source cmd tail and verifies the child PSP:0x80..0xFF contains at most 126 command bytes plus the canonical `0x0D` terminator.
- The same regression covers a source segment pointing at the kernel CS and verifies EXEC fails cleanly.
- Existing EXEC tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/exec.inc:228-245` (`exec_copy_command_tail`).
- The `mov word [es:0x80], 0x0D00` at line 230 initializes the length+CR but is overwritten by the 128-byte copy immediately after.
- Discovered during a whole-system review on 2026-06-06.
