# Fail tests on QEMU timeout by default

## Summary

`testlib.finish_qemu` computes a `timed_out` flag, but `run_serial_image` discards it (`output, _ = run_qemu_capture(...)`, scripts/testlib.py:131-140), and ~49 tests unpack `output, _ =` the same way; only 4 tests check the flag (e.g. scripts/test_cd_86box.py:107-124). A test passes if its required markers were printed before the kernel wedged — the run silently burns the full timeout, SIGTERMs QEMU, and reports PASS. Nothing distinguishes "exited via HALT" from "hung after printing PASS" unless a test happens to require "HALT" in its markers.

## Requirements

- Make `run_serial_image`/`run_simple_serial_test` (and the capture helpers) treat a timeout as failure by default, with an opt-out parameter for tests that legitimately run until killed.

## Acceptance Criteria

- A deliberately hanging kernel image makes a simple marker test fail with a clear timeout message; the full `make test` suite still passes (opting out only where genuinely needed, each with a one-line justification).

## Resolution

Resolved 2026-06-10. run_serial_image (and run_simple_serial_test via its new allow_timeout parameter) treats a QEMU run that burns the full timeout without reaching a stop or fail marker as a failure, printing the serial output with a clear "without reaching a stop marker" message. No suite test needed the opt-out -- every DEFAULT_TESTS entry reaches HALT or a fail marker. The new scripts/test_timeoutguard.py pins the behavior with a deliberately hung image (prints its PASS marker, then jmp $).
