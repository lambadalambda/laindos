# Use program size in exec_com_dyn stack top

## Summary

`exec_com_dyn` in `src/kernel/exec.inc` builds a stack top from the MCB size, but uses `mov ax, [ds:3]; cmp ax, 0x1000; jb .small_stack` where `ds` was set to `prog_seg-1` (the MCB) and `[ds:3]` is the MCB's own size field in paragraphs, not the program segment's free memory. For a small program allocated at the top of a large free block, this can produce a `com_stack_top` that lies outside the allocated program region, and subsequent `push`/`call` will overwrite the MCB.

## Resolution

Closed on 2026-06-06 as a non-issue. Investigation of `alloc_mem_direct` in `src/kernel/memory_mcb.inc:18-77` showed that `[ds:3]` is set to `am_req` (the requested paragraphs from the caller), not the MCB size including itself. For EXEC, `am_req` is `prog_par`, which is the program's size in paragraphs (excluding the 1-paragraph MCB). So `[ds:3]` correctly reflects the program region size, and the existing stack-top calculation is correct:

- For a 256-byte program: `[ds:3] = 16`, `com_stack_top = 16 * 16 - 2 = 254`. Program region is 256 bytes (offsets 0-255), so SP=254 is at the end of the region. Correct.
- For a 64 KiB program: `[ds:3] = 4096`, `cmp ax, 0x1000` takes the `jae` branch, `com_stack_top = 0xFFFE`. Program region is 65536 bytes, so SP=0xFFFE is at the end. Correct.

The new MCB chain is `orig + am_req + 1` (one paragraph past the program), so the program region is exactly `am_req` paragraphs and the stack top is correctly bounded.

No code change needed. The original review's claim that `[ds:3]` is the "MCB's own size field" conflates the program size with the total owned paragraphs. The LainDOS allocation layout stores the program size at `[ds:3]`, with the chain pointer to the next MCB computed as `orig + am_req + 1`.

## Notes

- Relevant code: `src/kernel/exec.inc:1211-1236` (`exec_com_dyn`), `src/kernel/memory_mcb.inc:18-77` (`alloc_mem_direct`).
- Original whole-system review entry from 2026-06-06.
