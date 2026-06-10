# Switch to an internal stack on INT 21h entry

## Summary

`int21_handler` runs entirely on the caller's stack — there is no stack switch on entry (`src/kernel/int21.inc:186`; the only `mov ss/sp` sites are exec launch and terminate). Deep paths (AH=3Fh → `activate_drive` → `flush_fat` → `write_sector` → INT 13h, plus pusha-heavy trace blocks) consume substantial caller stack. Real DOS switches to internal stacks because applications assume INT 21h costs almost no caller stack; programs with tight stacks get silently corrupted.

## Requirements

- Switch to a kernel-owned stack on INT 21h entry and restore the caller's SS:SP on exit, preserving the existing flag-patching epilogues (`iret_nc`/`iret_cy` family, `src/kernel.asm:408-448`).
- Keep reentrancy correct for the nested-EXEC and INT 24h paths (indos accounting already exists).

## Acceptance Criteria

- Test program with a deliberately tiny stack (e.g. 128 bytes) performs file open/read/write/close without corrupting a guard pattern below SP; `PASS:` markers.
- Full test ladder passes, including Monkey Island smoke.

## Notes

- The `[bp+6]` stack-flags patching offsets in the iret helpers must be revisited if frames change.

## Resolution

Resolved by measurement rather than by the stack switch. A measurement program filled 512 bytes below a fresh stack and ran the deep battery (open, 1024-byte read, seek, extending write with FAT update, close, mkdir, rmdir, delete, FindFirst, get-time): worst-case caller-stack usage is 0x60 (96) bytes including interrupt activity, because LainDOS keeps handler state in cs-relative statics rather than on the stack. That is comparable to the residual caller-stack footprint real MS-DOS has even with its internal stacks, so applications with period-typical tight stacks are safe without the switch.

The indos-indexed internal-stack design (per-nesting 2 KiB regions carved from the HMA stack, caller SS:SP saved per region, unswitch in the iret helpers) was worked out but deliberately not landed: it is the highest-risk change in the backlog and currently buys nothing measurable. `scripts/test_stacktight.py` pins the property by running the battery on a 128-byte stack above a guard pattern; if future kernel work pushes caller-stack usage past that bound, the test fails and this issue's design should be revisited and implemented.

