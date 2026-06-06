# Validate EXEC env source segment

## Summary

`update_exec_environment_path` in `src/kernel/exec.inc` reads `exec_env_src_seg` verbatim from the parent-supplied EXEC parameter block and then walks up to `ENV_SIZE_BYTES` of that segment into the child's allocated environment block. A parent can point this at any segment (kernel CS, BIOS data area, another PSP) and the kernel will copy that memory into the child env, which the child then reads normally. This is a kernel-memory disclosure primitive disguised as `INT 21h` AH=4Bh.

## Requirements

- Validate the caller-supplied environment segment before walking it.
- Reject segments that point at reserved regions (IVT, BDA, kernel, boot sectors) and return a DOS-compatible error.
- Preserve support for legitimate parent-supplied env blocks (caller PSP or caller-allocated env).
- Keep the existing overflow guard (`.env_overflow` already returns AX=8) and the rollback path intact.

## Acceptance Criteria

- A regression passes an EXEC param block whose env_seg points at the kernel CS (`0340h`) and verifies EXEC fails cleanly without copying any bytes into the child env.
- The same regression covers env_seg pointing at the IVT, BDA, and video memory ranges; all fail cleanly.
- A legitimate parent-supplied env_seg (pointing at a real env block) still works.
- Existing EXEC, envmcb, and envpath tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/exec.inc:265-294` (`update_exec_environment_path` and `.copy_env`).
- The destination buffer is already bounded by `cmp di, bx` (bx=`ENV_SIZE_BYTES`), so the disclosure is bounded but unvalidated.
- Discovered during a whole-system review on 2026-06-06.
