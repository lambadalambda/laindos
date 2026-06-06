# Use program size in exec_com_dyn stack top

## Summary

`exec_com_dyn` in `src/kernel/exec.inc` builds a stack top from the MCB size, but uses `mov ax, [ds:3]; cmp ax, 0x1000; jb .small_stack` where `ds` was set to `prog_seg-1` (the MCB) and `[ds:3]` is the MCB's own size field in paragraphs, not the program segment's free memory. For a small program allocated at the top of a large free block, this can produce a `com_stack_top` that lies outside the allocated program region, and subsequent `push`/`call` will overwrite the MCB.

## Requirements

- Compute the program size from the program segment's own region, not the MCB size.
- Use the program MCB's `size - 1` minus any PSP or header overhead as the free memory within the program region, or fall back to a hard cap (e.g. `0xFFFE`) with a guard check.
- Verify the new stack top is inside the program region before passing it to the user program.
- Add focused regression coverage for a small program allocated at the top of a large free block.

## Acceptance Criteria

- A regression pre-allocates a small program block at the top of a free block, EXECs it, and verifies the user program's stack writes stay inside the program region (no MCB corruption).
- The same regression verifies the stack top is still within the program region for a small program in a small MCB.
- Existing EXEC tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/exec.inc:1211-1236` (`exec_com_dyn`).
- The fix is to read the program-region size, not the MCB size, when computing `com_stack_top`.
- Discovered during a whole-system review on 2026-06-06.
