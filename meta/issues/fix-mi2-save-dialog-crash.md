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

## Investigation (2026-06-10)

The crash is a regression from `2b88c89` (relocate kernel to the HMA), pinned by a
mixed-mode bisect (candidate src/programs against build/test scripts pinned at
b28cfad, banner markers patched, boot -DFAT12 bridged). Two earlier naive bisect
verdicts were artifacts: the banner rename (marker drift) and the vendor bundling
commit (untestable gap).

Proven by experiment matrix (all on the current kernel unless noted):

| Config | Result |
|---|---|
| pre-HMA kernel (8e35865) | PASS |
| pre-HMA kernel + A20 forced on | PASS (A20/wraparound exonerated) |
| HEAD kernel, ENABLE_XMS=0 | CRASH (XMS advertisement exonerated) |
| HEAD kernel, MCB_START=0x1000 | PASS |
| HEAD kernel, MCB_START=0x640, MEM_TOP=0x9600 (old pool size) | CRASH (pool size exonerated) |
| HEAD kernel, MCB_START=0x680/0x800/0xA00/0xC00 | CRASH |

So the trigger is the program load/allocation segment: MONKEY2 works when the MCB
chain starts at 0x1000 and crashes for every tested base at or below 0xC00; the
threshold lies in (0xC00, 0x1000]. The crash (`EXC 06 at 0674:FF0C`, mid-instruction
entry into real code) happens during startup resource parsing of MONKEY2.001
(byte-at-a-time reads to ~0x3E6B66, two short relative seeks, then the wild jump) --
the savegame never gets written because the game dies before the dialog flow
completes. MONKEY2 installs an INT 08 hook (iMUSE) beforehand; Ascendancy runs from
the same image at the same low segments without issue, so a general kernel/FAT
corruption is unlikely -- this looks like MONKEY2/iMUSE segment-dependent pointer
math, or a LainDOS allocator/loader edge only MONKEY2's allocation pattern
(binary-search to the largest block, base 0x30D2 when failing) exercises.

Next steps: bracket the exact MCB_START threshold (0xE00, 0xF00) and inspect what is
semantically special about it; extend the kernel EXC dump with a stack snapshot to
identify the bad jump's caller; or replay MONKEY2's exact alloc/open/read sequence in
a test program to rule the allocator in or out.
