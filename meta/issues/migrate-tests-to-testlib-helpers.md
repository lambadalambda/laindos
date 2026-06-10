# Migrate long-hand tests to testlib helpers

## Summary

Roughly 3,000 lines (~20% of scripts/) are copy-pasted boilerplate that testlib already provides: 81 tests define their own `build_image()`, 41 carry a byte-identical 8-line `run(cmd)` (= `testlib.run_cmd`), 79 inline the standard QEMU serial arg block (= `run_serial_image`, used by only 25), and 45 inline marker-check loops (= `check_markers`, used by 53). Only 14 tests use the one-call `run_simple_serial_test`, at ~25 lines each vs ~80 for the long-hand copies. Every inline copy is a place where a global QEMU-flag change must be hand-edited.

## Requirements

- Migrate the long-hand tests onto `run_simple_serial_test`/`build_nasm_test_image`/`run_serial_image`/`check_markers`; extend testlib only where a test has a genuine extra need.
- Do in batches (e.g. 10-20 tests per commit) so each commit stays reviewable and the ladder passes between batches.

## Acceptance Criteria

- `make test` passes after every batch; final grep shows no remaining `def run(cmd):` duplicates and few-to-no inline `-serial stdio` arg blocks outside testlib and the game/media scripts.

## Notes

- Continuation of the archived continue-qemu-test-harness-consolidation / standardize-serial-qemu-test-boilerplate work; coordinate with [Fail tests on QEMU timeout by default](fail-tests-on-qemu-timeout.md) so migration picks up the new default.

## Resolution (batch 1, 2026-06-10)

Removed all 41 byte-identical test-script `run(cmd)` copies and the 7 near-identical copies in the build scripts (testlib.run_cmd now also prints "Command failed: <cmd>" on error, matching the richer variant); run_monkey_full_bochs.py keeps its genuinely different non-capturing runner. 23 tests with the exact canonical floppy QEMU block now call run_serial_image (picking up the fail-on-timeout default). Net -650 lines. Also fixed the broken `make test-attached-hd-shell` target found along the way (it never passed the image path; now depends on extras-hd and passes it). Remaining work for later batches: tests with custom drive_opts/extra QEMU args, and the inline marker-check loops that could move to check_markers.
