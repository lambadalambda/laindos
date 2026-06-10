# Fix the Monkey Island 2 save dialog crash

## Summary

`scripts/test_mi2_save.py` (re-listed by the orphaned-tests cleanup, runnable via `make test-mi2-save`) fails: driving the MI2 save dialog crashes with `EXC 06 at 0674:FF0C` (invalid opcode; the byte dump `0A 15 0E E8 FE 08 83 C4 04 9A ...` looks like mid-instruction data, so execution jumped into garbage). The test was wired to no target when found, so it is unknown which change introduced the crash — it may date back to any kernel work since the test was written. The save flow exercises file create/write plus keyboard input through the dialog, so likely suspects are the recent write-path or console changes, but bisecting against older kernels is the honest first step.

## Requirements

- Bisect or trace the crash to the faulting DOS call sequence (TRACE_DOS build plus the EXEC/serial traces should narrow it).
- Fix the kernel bug; MI2 saving must complete and the saved game must reload.

## Acceptance Criteria

- `make test-mi2-save` passes, including its screenshot assertions.
- Full `make test` suite stays green.

## Notes

- The test also has a hand-rolled QEMU pipe race (double-reading proc fds); migrate it to testlib helpers as part of [Migrate long-hand tests to testlib helpers](migrate-tests-to-testlib-helpers.md).
