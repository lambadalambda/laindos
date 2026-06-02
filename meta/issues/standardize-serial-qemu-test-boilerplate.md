# Standardize Serial QEMU Test Boilerplate

## Summary

Many `scripts/test_*.py` programs still repeat the same build-image, run-serial-QEMU, and marker-check boilerplate. This makes new tests longer than necessary and increases the risk of subtly divergent timeouts or QEMU arguments.

## Requirements

- Add or extend a `testlib.py` helper for standard NASM test images that run under serial QEMU and check required markers.
- Migrate representative simple tests without hiding per-test assertions.
- Preserve per-test build directory isolation.
- Keep specialized game-smoke or multi-disk tests explicit when they need custom behavior.

## Acceptance Criteria

- At least five simple serial regression scripts use the standardized helper.
- Migrated tests still produce useful failure messages with missing markers and serial output paths.
- Migrated tests pass individually.
- `make test` passes.

## Notes

- Relevant existing shared harness: `scripts/testlib.py`.
- This is a follow-up to the archived `Extract Shared QEMU Test Harness` and `Continue QEMU Test Harness Consolidation` issues.
