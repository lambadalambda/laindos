# Support unaligned overlay relocation tables and cache reloc sectors

## Summary

`overlay_apply_relocs` rejects any relocation entry that straddles a 512-byte sector boundary (`cmp bx, 508 / ja .entry_crosses_sector`, `src/kernel/exec.inc:829-832`), turning legal MZ files with non-4-byte-aligned tables into hard load failures. It also calls `overlay_read_reloc_sector` once per 4-byte entry, and that routine re-walks the FAT chain from `ov_cluster` every time (exec.inc:869-924) — re-reading the same sector hundreds of times for a large table.

## Requirements

- Handle entries that span sectors (e.g. buffer two sectors or assemble the entry bytewise).
- Cache the current reloc sector and the chain position so sequential entries do not re-walk the FAT.

## Acceptance Criteria

- Test EXE with an odd-offset relocation table loads correctly as an overlay; a large-reloc overlay (existing bigreloc material) loads measurably without per-entry chain walks (verify by serial trace counter or just correctness plus code inspection); `PASS:` markers.
- Existing overlay/badreloc/bigreloc tests pass.
