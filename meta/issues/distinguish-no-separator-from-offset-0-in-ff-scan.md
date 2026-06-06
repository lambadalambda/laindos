# Distinguish no-separator from offset 0 in ff_scan

## Summary

`.ff_scan` and `ff_scan_done` in `src/kernel/int21.inc` use `0` as both "no separator found" and a valid offset into the path, so a path at DS:0 that starts with `\` (e.g. `"\FILE.TXT"`) is misclassified as a bare name and parsed as a literal filename beginning with `\`, producing garbage in `name_buf`.

## Requirements

- Use a distinct sentinel (e.g. `0xFFFF` or a separate boolean) for "no separator found" instead of overloading the offset value.
- Audit every consumer of the `ff_*` path-state variables to make sure they handle the new sentinel correctly.
- Add focused regression coverage for paths at DS:0 starting with `\`, `/`, and a normal name.

## Acceptance Criteria

- A regression calls `FindFirst` with a path whose DS:0 byte is `\` and verifies the kernel correctly classifies the path as rooted.
- The same regression covers `/FILE.TXT` and `FILE.TXT` and verifies all three are classified correctly.
- Existing FindFirst/FindNext tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:4236-4254` (`.ff_scan` and `ff_scan_done`).
- Discovered during a whole-system review on 2026-06-06.
