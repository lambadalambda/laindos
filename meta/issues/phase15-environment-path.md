# Phase 15: Environment and PATH

## Summary

Make the DOS environment useful enough for a shell and child program lookup.

## Requirements

- Populate environment variables such as `COMSPEC`, `PATH`, and `PROMPT`.
- Pass a valid environment segment to child programs.
- Teach the shell to resolve commands through the current directory and `PATH`.
- Try `.COM` and `.EXE` extensions when no extension is supplied.
- Preserve the executable path tail after the double-null environment terminator.

## Acceptance Criteria

- The shell can launch commands by basename without an extension.
- Child programs can inspect a valid environment block.
- `PATH` lookup finds programs outside the current directory.
- Existing MI2 executable-path behavior remains intact.

## Notes

- Environment editing commands such as `SET` can be added later if needed.
