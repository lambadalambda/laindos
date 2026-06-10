# Fix INT 21h clock rollover, drift, and frozen set-time state

## Summary

AH=2Ch (`src/kernel/int21.inc:1883-1966`) has three time bugs: (a) the INT 1Ah AH=0 midnight-rollover flag in AL is discarded, so the date statics (`src/kernel.asm:3099-3102`) never advance past midnight; (b) the tick-to-time conversion subtracts 0xFFF0 (65520) ticks per hour instead of the true ~65543.33, drifting about 1.3 seconds fast per hour; (c) once AH=2Dh sets `time_set=1`, `.gt_stored` returns the frozen stored values forever — the clock stops advancing entirely after any set-time call.

## Requirements

- Honor the midnight flag by advancing the stored date.
- Use the standard ticks-to-time conversion (e.g. the 65543/65536 correction or compute from ticks*10/182.065 equivalents) within +/-1 second per day.
- After AH=2Dh, store an offset against the BIOS tick count rather than freezing the value, so time continues to advance.

## Acceptance Criteria

- Test: set time via AH=2Dh, busy-wait ~2 seconds of ticks, read AH=2Ch and verify it advanced; midnight rollover advances the date (settable by forcing the BIOS tick count near 0x1800AF); `PASS:` markers.
- Existing datetime/timeoffset tests pass.
