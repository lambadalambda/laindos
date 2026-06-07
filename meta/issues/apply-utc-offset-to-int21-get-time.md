# Apply UTC offset to INT 21h get-time

## Summary

`.get_time` in `src/kernel/int21.inc` decodes the BIOS `INT 0x1A` ticks as if they were local time, with no UTC→local offset. On hosts whose BIOS clock is UTC (common in QEMU with `-rtc base=utc`), `INT 21h` AH=2Ch returns UTC instead of the user's local time. Time-set (`AH=2Bh/2Dh`) and file-time (`AH=57h`) are consistent with the BIOS clock and are not affected.

## Requirements

- Convert the BIOS clock from UTC to local time when returning `AH=2Ch`.
- Pick a default timezone offset (host-passed via boot config, or `-LTZ` minutes in the kernel command line, or a small TZ env var).
- Document the chosen mechanism and keep the offset testable from a focused regression.
- Add a focused regression that sets a known UTC tick value and verifies `AH=2Ch` returns the expected local time.

## Acceptance Criteria

- A regression sets a known UTC `INT 0x1A` tick and verifies `AH=2Ch` returns the correct local time for at least one non-zero offset.
- The same regression verifies a zero offset still returns the BIOS clock as-is.
- Existing time-related tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:1849-1912` (`.get_time`).
- The BIOS `INT 0x1A` ticks count midnight as zero and roll over at 24:00; the offset must be applied modulo 24 hours.
- Discovered during a whole-system review on 2026-06-06.
- Completed on 2026-06-07 with build-time `UTC_OFFSET_MINUTES` (default `0`) normalized modulo 24 hours. The offset applies only to BIOS-derived `AH=2Ch`; time explicitly set with `AH=2Dh` is returned as stored. `scripts/test_timeoffset.py` covers zero, positive, negative, and hour-wrap offsets.
