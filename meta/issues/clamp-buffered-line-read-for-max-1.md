# Clamp buffered line read for max=1

## Summary

A whole-system review on 2026-06-06 flagged `.read_line_buffered` for what appeared to be a protocol drift at the max=0/max=1 boundary. Investigation on 2026-06-06 confirmed the kernel's behavior already matches DOS spec and is consistent: max=0 returns immediately with count=0 and no CR written; max=N for N>=1 allows up to N-1 chars, writes the actual count, and writes CR at offset count+2. The review's "inconsistent buffer" claim was a misreading of the dec-and-compare protocol.

No code change needed. The test added as part of this issue (`scripts/test_linebuf.py`) locks in the current behavior so future regressions are caught.

## Resolution

Closed as a non-issue on 2026-06-06 after empirical verification with `scripts/test_linebuf.py`:

- max=0: kernel sets count byte to 0 and returns immediately; no CR written, no other buffer bytes modified. The `test cl,cl / jz .rl_done` short-circuits before the dec.
- max=1: kernel dec cl to 0; the `cmp bl, cl / jae .rl_loop` gate rejects every keystroke (bl >= 0 is always true), so up to 0 chars are stored. On Enter, count=0 and CR is written at si+2. This is "no input possible, CR at offset 2" — option B from the original requirements.
- max=N (N>=2): kernel dec cl to N-1; up to N-1 chars stored, count byte reflects actual chars, CR at offset count+2. The `scripts/test_linebuf.py` regression covers max=3 with 2 chars typed.

## Notes

- Relevant code: `src/kernel/int21.inc:412-465` (`.read_line_buffered`).
- New test: `tests/programs/linebuf.asm` + `scripts/test_linebuf.py`.
- Discovered during a whole-system review on 2026-06-06.
