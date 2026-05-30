# Fix Process Memory Release After Program Exit

## Summary

External compatibility feedback reports that after finishing some games the system usually needs a reboot because later software complains about insufficient memory. This suggests process-owned memory is not always being released, or released memory is not being made reusable, after program termination paths.

## Requirements

- Reproduce the post-game or repeated-launch low-memory failure with a focused test, utility, or game smoke.
- Audit all termination paths that should free process resources, including `INT 20h`, `INT 21h AH=00h`, `INT 21h AH=4Ch`, and child returns to the shell or parent process.
- Verify MCB blocks owned by the terminating PSP are released or coalesced correctly, including program memory, environment blocks, and child-owned allocations.
- Preserve parent shell memory, environment ownership, open standard handles, and return-code behavior.
- Add a regression that catches leaked process-owned memory across repeated EXEC or game-like launch/exit cycles.

## Acceptance Criteria

- A repeatable repro demonstrates the memory leak or fragmentation problem before the fix.
- The repro passes after the fix without requiring a reboot between program runs.
- `make test` passes.
- At least one representative game or launcher that previously required a restart can return to the shell and launch another program without a false out-of-memory failure.

## Notes

- Reported symptom: "you need to restart the system after you're done with the game - memory ain't freed properly so software will complain about lack of memory."
- Related archived work: environment blocks are MCB-backed, but this report suggests there are still termination or ownership cases not covered by existing regressions.
- Root cause found: normal process termination released MCB ownership for the terminating PSP but did not coalesce the newly-adjacent free MCBs, so child environment, program, and child-owned allocations fragmented the largest reusable free block.
- Added `tests/programs/memrel.asm`, `tests/programs/memrchld.asm`, and `scripts/test_memrelease.py`; the regression failed before the fix with `FAIL: MEMREL LEAK` and passes after adding a termination-time free-MCB coalescing pass.
- Verification passed with `python3 scripts/test_memrelease.py`, `python3 scripts/test_envmcb.py`, `python3 scripts/test_tsr.py`, `make test` (`74/74`), and `make test-game-smokes`.
