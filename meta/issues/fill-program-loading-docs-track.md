# Fill Program Loading Documentation Track

## Summary

Expand the interactive documentation with a program-loading track that explains PSP setup, `.COM` loading, MZ `.EXE` loading, relocation, EXEC parent/child behavior, overlays, and termination cleanup.

## Requirements

- Replace the current programs placeholder in `docs/site/` with a real track.
- Explain PSP fields, command tails, FCBs, default handles, environment blocks, and terminate vectors.
- Document `.COM` and MZ `.EXE` load paths, relocation bounds, stack setup, and handoff registers.
- Document EXEC parameter blocks, custom environments, parent/child return codes, overlays, and termination flushing.
- Include source excerpts and references to loader-focused tests.

## Acceptance Criteria

- The programs sidebar entry renders a complete walkthrough rather than a placeholder.
- The track shows how LainDOS moves from shell command to child process and back.
- The track links to tests such as COM/EXE, PSP, EXEC, EXEC env, overlay, return code, bad relocation, and termination flush.
- Local site smoke confirms the track renders without console errors.

## Notes

- Keep this track synchronized with any future loader refactors.
