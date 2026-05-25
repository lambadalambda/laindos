# Extract Shared QEMU Test Harness

## Summary

The Python QEMU test scripts duplicate image-building, process launch, monitor socket, output reading, and marker-checking code.

## Requirements

- Introduce a small shared helper module for common QEMU test operations.
- Migrate scripts incrementally, starting with the newest or most similar tests.
- Keep each test's assertions clear and local to that test.

## Acceptance Criteria

- At least three representative tests use the shared helper without losing coverage.
- Migrated tests pass individually.
- `make test` passes after each migration batch.
