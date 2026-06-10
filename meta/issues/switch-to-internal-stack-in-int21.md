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
