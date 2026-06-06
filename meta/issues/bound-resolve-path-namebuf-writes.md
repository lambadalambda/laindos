# Bound resolve_path name_buf writes

## Summary

`resolve_path`'s `.rp_copy` loop in `src/kernel/path_dir.inc` writes path component bytes into the 11-byte `name_buf` (`src/kernel.asm:3208`) via `stosb` with no length cap. A path component longer than 11 chars without an embedded dot overflows past `name_buf` directly into the adjacent `handles` table (`src/kernel.asm:3210`), letting any program that calls a path-taking `INT 21h` API clobber kernel file-handle state (`H_USED`, `H_CLUSTER`, `H_POS`, `H_SIZE`, etc.) with mostly attacker-controlled bytes. `parse_83name` at `src/kernel/path_dir.inc:1755` and `1760` already has the matching `cmp di, name_buf+8`/`name_buf+11` `jae` guards that `.rp_copy` is missing.

## Requirements

- Bound the `stosb` write in `resolve_path`'s `.rp_copy` loop so it cannot write past `name_buf+11`.
- Preserve current behavior for legal 8.3 components and dot-terminated extensions.
- Refuse path components that exceed 11 chars (or fail with a clear DOS error) rather than silently truncating them.
- Add focused regression coverage for an overlong component in both the leading and trailing position of a path.

## Acceptance Criteria

- A regression creates a path whose leading or middle component is longer than 11 chars and verifies the kernel `handles` table is unchanged after the call.
- Existing path-resolution tests (FindFirst, open, chdir, exec, rename, delete) still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/path_dir.inc:1047-1067` (`.rp_copy` loop), `src/kernel/path_dir.inc:1060` (`stosb`), `src/kernel.asm:3208` (`name_buf: times 11 db 0`), `src/kernel.asm:3210` (`handles: times MAX_HANDLES * HANDLE_SIZE db 0`).
- The matching length-capped write is at `parse_83name` lines 1755 and 1760.
- Discovered during a whole-system review on 2026-06-06; described as a write-what-where over all 20 handles.
