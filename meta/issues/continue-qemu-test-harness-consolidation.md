# Continue QEMU Test Harness Consolidation

## Summary

Continue reducing duplicated Python QEMU test boilerplate after the initial shared serial and headless smoke helpers.

## Requirements

- Consolidate repeated image-building, command-runner, and marker-check patterns in representative `scripts/test_*.py` files.
- Preserve per-test build directory isolation and specialized QEMU options.
- Keep assertions local to each test so failures remain easy to diagnose.
- Avoid changing game-smoke behavior unless a test needs a harness bug fix.

## Acceptance Criteria

- At least three additional non-smoke QEMU regression scripts use shared helpers for duplicated boilerplate.
- Migrated tests pass individually.
- `make test` passes.

## Notes

- Follow-up to the archived `extract-shared-qemu-test-harness.md` issue.
- The first harness batch added serial-output helpers, parallel per-test build directories, and headless game-smoke helpers.
