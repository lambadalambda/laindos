# Cover AH=57h File Time Persistence

## Summary

Strengthen focused coverage for `INT 21h AH=57h` get/set file date and time so timestamp updates are verified through handle reads, `FindFirst`, reopen, and the persisted directory entry.

## Requirements

- Verify newly created file handles report the default FAT date/time.
- Verify `AX=5701h` set date/time updates the open handle and survives close/reopen.
- Verify `FindFirst` returns the set date/time from the directory entry.
- Verify the disk image directory entry contains the set date/time after the test run.
- Verify unsupported `AH=57h` subfunctions fail with invalid function on a valid handle.

## Acceptance Criteria

- A focused regression covers the date/time persistence paths.
- Existing save/write, find-time, and register-preservation coverage still passes.
- `make test` passes.
