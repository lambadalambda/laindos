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
