# Wrap Environment Blocks In MCBs

## Summary

Child PSPs currently point `PSP:002Ch` at a fixed `ENV_SEG` outside the MCB arena, and all processes share the same environment block.

## Requirements

- Allocate environment blocks from the MCB arena or otherwise provide a DOS-compatible MCB owner for `PSP:002Ch`.
- Avoid unwanted shared mutable environment state between parent and child processes.
- Preserve the existing `COMSPEC`, `PATH`, `PROMPT`, and executable-path tail behavior.

## Acceptance Criteria

- A regression can inspect the environment MCB and confirm it belongs to the child PSP or valid owner.
- Existing environment/PATH tests pass.
- `make test` passes.

## Notes

- This is likely required for installers, TSRs, and programs that walk the MCB chain.
