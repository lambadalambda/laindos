# Fix 64K destination wrap in overlay copy

## Summary

`overlay_copy_range` detects the 64K destination wrap only after `rep movsb` has run (`src/kernel/exec.inc:1133-1141`): the carry of `add ax, [cs:ov_chunk]` advances `ov_dst_seg`, but a chunk that crosses offset 0xFFFF wraps DI mid-copy and writes the remainder at `ov_dst_seg:0000`. With a standard 0x20-byte MZ header every chunk is misaligned (offset ≡ 480 mod 512), so any AH=4Bh AL=3 overlay larger than 64K overwrites its own load segment start while leaving a hole in the next 64K window. The CD variant (exec.inc:1226-1240) has the identical bug with 2048-byte chunks.

## Requirements

- Split chunks at the 64K boundary (or normalize ES:DI per chunk) so no `rep movsb` crosses offset 0xFFFF, in both the FAT and CD overlay copy loops.

## Acceptance Criteria

- Test: load a >64K MZ overlay with a 0x20-byte header via AH=4Bh AL=3 and verify bytes around every 64K boundary and at offset 0 of the load segment; `PASS:` markers on serial.
- Existing overlay tests pass.

## Notes

- `load_cd_file_direct` (exec.inc:353-357) is safe because its offsets stay 2048-aligned from 0; do not "fix" it the same way without need.
