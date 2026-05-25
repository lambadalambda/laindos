# Deduplicate INT 21h Exit Frames

## Summary

Many INT 21h handlers duplicate hand-written register unwind sequences, increasing the chance of register corruption when adding new paths.

## Requirements

- Identify the common handler frame patterns and introduce NASM macros or small structured helpers for matching pop/return paths.
- Preserve caller-visible register behavior covered by existing register-preservation tests.
- Keep the refactor mechanical and separately reviewable.

## Acceptance Criteria

- Existing register-preservation and shell/EXEC tests pass.
- The most duplicated open/create/read/write close paths have fewer manual unwind copies.
- `make test` passes.
