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

## Investigation update (2026-06-11)

The failure is **nondeterministic** (~30-50% of runs at a fixed build), which
invalidates the original single-run-per-step bisect. Re-validated endpoints:
the pre-HMA revision b28cfad passes the FULL save/reload choreography 6/6;
current kernels crash ~40% of runs and never complete the save flow even when
they do not crash. A statistical re-bisect (multiple runs per step,
save-ok/EXC classification) is the active workstream.

Key discoveries:

1. **The "EXC 06 at 0674:FF0C" reports were garbage.** QEMU `-d int,cpu`
   shows the only real #UD fired at CS=FFFF EIP=0x0D86 -- mid-instruction
   *inside exc06_handler itself*. Execution went wild, wandered into the
   handler body, and fell through `.real_invalid` printing whatever stack
   residue sat at [bp+2]/[bp+4] (constant 0674:FF0C across runs). That is why
   the "faulting bytes" always looked like valid code and why breakpoints on
   the reported address never fired. The EXC reporter needs a validity marker.
2. **Tick re-entrancy at the game handler**: the int log shows hardware INT 08
   delivered twice in a row with CPU at exactly 2A4A:0767 (the game's iMUSE
   timer handler entry) with IF=1 -- something chains into the non-reentrant
   handler with interrupts enabled and a second tick lands there.
3. Mechanism candidates exonerated by N>=6 run series at fixed builds:
   PS/2 mouse (off: 5/9 crash), XMS (off: 1/6), forced-IF removal alone (6/9),
   InDOS fix alone (2/6), InDOS fix + no forced IF (3/9). Single-sample
   experiments from 2026-06-10 (load segment / MCB_START / MEM_TOP / placement
   correlations) are all statistically void and superseded.
4. **Fixed for real along the way**: EXEC children now run with InDOS=0
   (commit 88a36ba; previously every program ran its whole life with InDOS
   elevated, breaking era ISR gating); the kernel exception dump now includes
   stack and registers.
5. docs/debug_log.md's Stunt Island entry documents the faithful interrupt
   model (STI inside the DOS body, preserve caller IF on return) as the
   eventual replacement for the IF-force shim; a staged patch exists at
   /tmp/faithful_if_patch.py but is unproven against this bug.

## Mechanism narrowed, not yet fixed (2026-06-11)

Experiments that closed out the original framing:

1. **iMUSE driver removal**: stripping the `.IMS` drivers (no INT 08 hook)
   eliminates the crash completely -- 0/6 vs ~40-50% baseline. The game's
   timer hook is a required ingredient; the kernel does not corrupt
   anything on its own.
2. **Tick batching**: the old kernel ran INT 21h with IF=0 and forced IF=1
   at IRET. QEMU accounting shows it silently dropped ~75%+ of timer ticks
   at the PIC during load and delivered survivors in bursts at IRET
   boundaries (always with InDOS=0) -- the bursty re-entrancy behind the
   original ~40% save-flow crash.
3. **Faithful interrupt model** (STI in the INT 21h body, caller IF
   preserved, STI at EXEC child entry, MS-DOS-style kernel dispatcher
   stack) is now in the kernel (15c8f37 + follow-up): correct semantics,
   139/139 suite, and the wandering-execution crash is gone. But MI2 now
   fails differently: all 291 Hz iMUSE ticks are delivered, ~99% land
   inside INT 21h (InDOS=1) because the game's poll loop lives in AH=0Bh,
   the InDOS-gated game-side iMUSE callback starves, and the game gives up
   at the intro-music sync point ("Overlay Alloc failed for
   C:\MI2\speaker.ims", then a clean exit).

SPEAKER.IMS internals (disassembled): MZ overlay; install reprograms the
PIT to ~291 Hz; the tick handler far-calls the game's iMUSE core every
tick (no InDOS check in the driver; the gate is in the game callback --
faking AH=34h to a zero byte makes the game exit instantly, so the gate
is load-bearing). BIOS INT 08 is chained every 16th tick.

Open question: what lets the callback keep up on real DOS. LainDOS's
keyboard-status and byte-read paths keep the CPU inside INT 21h for ~99%
of the load/poll phase (sampled: 74% of wall time inside BIOS INT 16h
AH=01 under the kernel's AH=0Bh path); real DOS's duty cycle is far
lower. Next lever: cut in-DOS wall time on those hot paths, or RE the
game-side callback's catch-up logic to find the precise starvation
threshold.
