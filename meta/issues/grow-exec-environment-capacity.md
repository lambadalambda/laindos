# Grow EXEC environment capacity beyond 256 bytes

## Summary

The child environment is capped at `ENV_PARAS equ 16` = 256 bytes including the trailing `dw 1` and full program path (`src/memory.inc:12`, `src/kernel/exec.inc:484-510`), and overflow fails the entire EXEC with error 8 rather than truncating. A parent that SETs a few variables (or whose own block plus the appended path exceeds ~170 bytes) can no longer launch any program. Real DOS supports environments up to 32K.

## Requirements

- Size the child environment block from the actual parent environment length plus the program path (rounded up to paragraphs), with a sane upper bound (e.g. 32K).

## Acceptance Criteria

- Test: parent builds a >256-byte environment via SET-equivalent writes, then EXECs a child that reads several variables and its PSP:2Ch path; `PASS:` markers.
- Existing envmcb/envoflow/execenv tests pass (update envoflow expectations if they encode the 256-byte limit).
