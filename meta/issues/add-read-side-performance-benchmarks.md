# Add Read-Side Performance Benchmarks

## Summary

Add generated benchmarks for the remaining read-side hot paths before changing
the implementation. The previous performance track covered writes, metadata,
drive switches, FAT16 allocation, and CD archive-cache behavior; the next track
needs stable counters for sequential reads, EXEC/overlay loads, FAT chain walks,
directory searches, and sequential CD reads.

## Requirements

- Build generated FAT16 and ISO media without requiring vendor game files.
- Measure `INT 21h AH=3Fh` sequential reads with 512-byte, 1 KiB, 4 KiB, and small 64-byte chunks.
- Measure EXEC or loader-style reads of a generated large program/image.
- Measure random seeks inside a large FAT file and report FAT chain-walk steps.
- Measure worst-case subdirectory path lookup in a generated large directory.
- Measure sequential CD reads separately from MIX-style alternating reads.
- Keep counters opt-in through `PERF_IO_COUNTS=1` and quiet in normal test runs.

## Acceptance Criteria

- A `make` benchmark target reports read-side counters and fails on missing or malformed output.
- The benchmark records physical read counts, transferred sectors or bytes where useful, and BIOS ticks for each phase.
- The benchmark output gives a clear baseline for later multi-sector read, read-ahead, and direct-load changes.

## Notes

- Start from the existing benchmark style in `scripts/bench_io_hot_paths.py`, `scripts/bench_cd_cache.py`, and `tests/programs/perfio.asm`.
- Prefer one focused benchmark target if the phases stay quick; split into multiple targets if run time grows too much.
