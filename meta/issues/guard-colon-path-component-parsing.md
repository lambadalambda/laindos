# Guard colon handling in path component parsing

## Summary

In `resolve_path`, a component beginning with `':'` is handled by two unconditional `inc si` (`src/kernel/path_dir.inc:982-987`). For a path ending in `':'` (e.g. `open("FOO\:")` or a stray `":"`), the second increment steps past the NUL terminator and the parser keeps scanning adjacent caller-segment memory for separators — an out-of-bounds read with unpredictable resolution results.

## Requirements

- Check for the terminator between the two increments (or reject mid-path `':'` outright with error 3, matching DOS path syntax rules).

## Acceptance Criteria

- Test: opening `FOO\:`, `:`, and `A::B` returns a clean path error; `PASS:` markers.
- Existing path canonicalization tests pass.
