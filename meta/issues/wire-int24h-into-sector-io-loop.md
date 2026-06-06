# Wire INT 24h into sector_io_loop

## Summary

The `INT 24h` critical-error handler is installed and configured to return `al=3` (fail), but `sector_io_loop` never calls `int 0x24` when `int 0x13` fails. The handler resets the disk and retries, then returns CF=1 without ever presenting the error to the registered handler. The handler is currently dead code.

## Requirements

- Have `sector_io_loop` call `int 0x24` when `int 0x13` returns an error and honor the return value (3=fail, 1=retry, 2=abort).
- Preserve the existing reset-and-retry behavior on a non-fatal error.
- Avoid recursing into the critical-error handler on a hard error that the handler itself returns fail for.
- Add focused regression coverage that simulates a sector read error and verifies the kernel returns CF=1 to the caller.

## Acceptance Criteria

- A regression installs a custom `INT 24h` handler that sets a global flag and returns `al=3`; the test triggers a sector read error and verifies the flag is set.
- A regression that relies on the existing retry-then-fail path still works when the handler is not installed.
- Existing FAT and filesystem tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel.asm:1578-1580` (INT 24h installation) and `src/kernel/disk.inc:36-56` (`sector_io_loop`).
- The current default behavior (handler returns `al=3`) and the kernel's existing retry-on-error are compatible: a future custom handler can decide to abort early, retry harder, or log and fail.
- Discovered during a whole-system review on 2026-06-06.
