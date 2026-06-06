# Fix asterisk wildcard in parse_83name

## Summary

`parse_83name` in `src/kernel/path_dir.inc` builds the 8.3 pattern `"????????   "` for a bare `*` and `"FILE????   "` for `FILE*`. RBIL says `*` should match the entire 8.3 name (i.e. fill both the name and the extension with `?`). The current code only matches files with no extension when the user supplies a bare `*` or a stem with a trailing `*`.

## Requirements

- Make bare `*` produce a pattern that matches all files (name=`????????`, ext=`???`).
- Make a stem with trailing `*` (e.g. `FILE*`) fill the name part with `?` past the stem and also fill the entire extension with `?`.
- Preserve behavior for stems without `*`, dot-terminated wildcards (`FILE.*`, `*.TXT`), and embedded `?` wildcards.
- Add focused regression coverage for the bare-`*`, stem-with-`*`, and `*` with explicit-extension cases.

## Acceptance Criteria

- A regression creates files `A.TXT`, `B`, and `C.EXE` in the same directory and runs FindFirst with `*`; all three match.
- A regression runs FindFirst with `B*` and verifies both `B` and `B.EXE` (if present) match.
- Existing FCB and path-parsing tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/path_dir.inc:1768-1793` (`.pl_star`, `.pl_name_star_fill`, `.pl_skip_to_dot`).
- Discovered during a whole-system review on 2026-06-06; the wrong wildcard semantics silently miss files with extensions.
