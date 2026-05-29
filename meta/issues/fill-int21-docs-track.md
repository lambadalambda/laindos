# Fill INT 21h Documentation Track

## Summary

Expand the interactive documentation with a complete `INT 21h` DOS API track that explains the dispatcher, implemented functions, register contracts, carry flag behavior, and the game-driven compatibility choices.

## Requirements

- Add a `docs/site/` track for `INT 21h` that replaces the current placeholder.
- Cover the dispatcher structure and how AH selects services.
- Document file handle APIs, process termination, EXEC, DTA, find APIs, attributes, timestamps, drive APIs, IOCTL, and allocation strategy at the level needed to read the implementation.
- Call out intentionally missing or deferred APIs and link them to the deferred compatibility issue where relevant.
- Include source excerpts that match current files and line numbers.

## Acceptance Criteria

- The `INT 21h` sidebar entry is no longer a placeholder.
- Each documented API group has prose, source excerpts, register/state notes, and at least one test or script reference.
- `README.md` links to the new track or describes where to find it.
- Local site smoke confirms the track renders without console errors.

## Notes

- Keep the track practical: focus on the APIs LainDOS implements and games/tests exercise.
- If implementation line numbers move while writing this, update the excerpts in the same change.
