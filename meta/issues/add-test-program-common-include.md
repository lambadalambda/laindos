# Add a common include for DOS test programs

## Summary

Of 120 programs in tests/programs/, only 4 use any `%include`. 98 repeat the same `push cs / pop ds` prologue, 113 the same AH=09h print, 114 the same AH=4Ch exit, 88 the same `fail:` epilogue with per-test `fail_xxx:` ladders, and 18 EXE tests duplicate an identical ~20-line MZ header block verbatim (e.g. filetest.asm:5-20 ≡ exemax.asm:5-21). Hundreds of duplicated lines that make new TDD tests more expensive than they need to be.

## Requirements

- Create `tests/programs/common.inc` with: program prologue macro, print-string helper, `FAIL_WITH msg` macro, pass/exit macro, and an MZ-header macro; migrate existing tests in batches.

## Acceptance Criteria

- `make test` passes after each migration batch; new-test boilerplate drops to a few lines (demonstrated by converting at least one full test); AGENTS.md/docs updated to point new tests at the include.

## Resolution

Resolved 2026-06-10 (first batch). tests/programs/common.inc provides COM_START (org + entry + DS=CS), PRINT_DOLLAR, EXIT_CODE, PASS_WITH/FAIL_WITH, and MZ_HEADER (assembles byte-identically to the long-hand EXE header, proven on exemax.asm). Converted hangloop.asm, switchar.asm, and exemax.asm as the demonstration; AGENTS.md points new test programs at the include. Remaining programs migrate opportunistically as they are touched -- the include is the standard for new tests from here on.
