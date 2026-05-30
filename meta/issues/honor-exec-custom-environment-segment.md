# Honor EXEC Custom Environment Segment

## Summary

`INT 21h AX=4B00h` currently builds a fresh default environment for every child. Honor a nonzero environment segment in the EXEC parameter block so callers can pass custom variables without LainDOS taking ownership of the parent-owned block.

## Requirements

- If the EXEC parameter block environment segment is zero, keep current default environment behavior.
- If the EXEC parameter block environment segment is nonzero, copy variables from that segment into the child environment.
- Do not reassign, mutate, or free a caller-provided environment block during child setup, termination, or failed EXEC cleanup.
- Preserve existing command-tail behavior.
- Update the Phase 19 compatibility matrix status for `AH=4B00h` or environment behavior.

## Acceptance Criteria

- A focused regression verifies a child sees a custom environment variable from the caller-provided segment.
- The regression verifies the caller-provided environment MCB remains parent-owned after child exit.
- Existing EXEC, environment, shell, and game smoke tests pass.

## Notes

- Later Duke Nukem 3D setup triage showed that spawned DOS/4GW children also need a child executable-path tail. Current behavior copies caller-provided variables into a child-owned environment block, appends the launched executable path, and leaves the caller-provided block parent-owned.
