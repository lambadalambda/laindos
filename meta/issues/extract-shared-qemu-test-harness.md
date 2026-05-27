# Extract Shared QEMU Test Harness

## Summary

The Python QEMU test scripts duplicate image-building, process launch, monitor socket, output reading, and marker-checking code.

## Requirements

- Introduce a small shared helper module for common QEMU test operations.
- Migrate scripts incrementally, starting with the newest or most similar tests.
- Centralize QEMU command-line defaults, timeout handling, process cleanup, serial output decoding, and PASS/FAIL marker checks.
- Preserve specialized options such as monitor sockets, hard-disk boot, and Sound Blaster flags where tests need them.
- Keep each test's assertions clear and local to that test.

## Acceptance Criteria

- At least three representative tests use the shared helper without losing coverage.
- Migrated tests pass individually.
- `make test` passes after each migration batch.

## Notes

- The review found more than 30 `scripts/test_*.py` files with repeated QEMU launch and output-check boilerplate.
- First step implemented shared serial-output early-stop helpers in `scripts/testlib.py` and migrated the default `make test` QEMU scripts away from fixed post-pass waits. `make test` now wraps each script with `scripts/run_test.py` so outliers print elapsed time. Broader image-building and marker-check consolidation remains open.
