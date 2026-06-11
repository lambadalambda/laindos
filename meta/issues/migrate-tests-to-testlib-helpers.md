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

## Resolution (batches 2-3, 2026-06-11)

run_serial_image gained boot_order and extra_args (floppy default
unchanged), letting the HD (order=c), -snapshot, two-drive (floppy +
IDE CD-ROM / IDE disk), and hard_disk-flag runner shapes migrate: 37
more tests dropped their inline QEMU argv blocks and hand-rolled
timed_out handling, picking up the fail-on-timeout default. The
canonical inline marker-check loops (including blank-line, named-list,
and no-forbidden variants) moved onto check_markers with identical
output. Net -704 lines across the two batches on top of batch 1's -650.

Final state vs acceptance: the only `def run(cmd):` left is
run_monkey_full_bochs.py's intentionally different non-capturing
runner; every remaining inline `-serial stdio` block is either an
interactive monitor/sendkey test (game/media and console/shell-typing
scripts, which need their own QEMU invocation with a monitor socket) or
test_boot_chain_bounds' custom stop_markers -- a legitimate direct
run_qemu_capture use. Remaining long-hand marker loops carry per-case
labels or multi-output checks that check_markers does not model.
