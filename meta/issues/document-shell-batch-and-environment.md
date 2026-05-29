# Document Shell Batch And Environment Behavior

## Summary

Add documentation for the LainDOS shell, batch startup, environment handling, PATH lookup, current directory behavior, and user-facing commands.

## Requirements

- Document how the shell starts, prints prompts, reads commands, and dispatches built-ins versus executable lookup.
- Explain `AUTOEXEC.BAT`, batch continuation after errors, environment variables, PATH search, and current directory state.
- Document supported commands and intentionally unsupported `COMMAND.COM` behavior.
- Include examples users can run in the interactive emulator.

## Acceptance Criteria

- The interactive site has a shell-oriented page or track section reachable from navigation.
- The page links to shell and batch-related tests.
- `README.md` points users to the shell docs for command examples.
- Local site smoke confirms the docs render without console errors.

## Notes

- This should make the interactive v86 page more useful after the user reaches `A:\>`.
