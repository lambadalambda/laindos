# Boot-launched COMs should get the largest free block, like real DOS

## Summary

The boot launcher (`BOOT_FILE` path) allocates the boot program with
`alloc_mem_direct_high` sized to the file, so the program lands in a
cramped block at the very top of the arena (just under the EBDA) and
`exec_com_dyn`'s small-block rule puts SP at the block top — a few KiB
past the code. Real DOS loads a COM into the largest free block (with
SP at 0xFFFE when the block is 64 KiB+), and COM programs assume they
own their segment. Any boot-launched test COM that uses an in-image
buffer larger than the slack silently overwrites its own stack.

Found the hard way: a CD chunk-read test put a 30 KiB buffer in its
image, the read ran past the block-top stack, smashed its own saved
INT 21h iret frame, and produced a "kernel CD hang" that took a long
debugging session to exonerate (see debug log 2026-06-12).

## Requirements

- Boot-launched COM programs get DOS-style memory: the largest free
  block, SP at 0xFFFE when 64 KiB is available.
- The shell keeps working (it is itself a boot-launched COM), and the
  suite's placement-sensitive tests stay green (era programs are
  placement-sensitive; see the MI2 placement note).

## Acceptance Criteria

- A test pins the boot COM's block size / SP (e.g. asserts SP=0xFFFE
  and a >= 64 KiB owned block when memory allows).
- Full suite passes.

## Notes

- The high allocation dates from earlier kernel layouts; check the
  history before assuming it is load-bearing.
