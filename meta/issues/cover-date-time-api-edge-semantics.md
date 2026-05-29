# Cover Date Time API Edge Semantics

## Summary

Strengthen `INT 21h AH=2Ah/2Bh/2Ch/2Dh` date and time compatibility around weekday reporting and boundary validation.

## Requirements

- Return the correct day of week after successful date changes.
- Preserve the previous date and weekday after invalid date changes.
- Cover valid and invalid boundary values for set-time behavior.
- Update the Phase 19 compatibility matrix status for date/time APIs.

## Acceptance Criteria

- A focused 16-bit regression exercises the implemented date/time behavior under QEMU.
- The regression is part of the default test suite.
- `make test` passes.
- The Phase 19 matrix notes the weekday and edge-case coverage.
