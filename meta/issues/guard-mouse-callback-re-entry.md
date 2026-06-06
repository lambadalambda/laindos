# Guard mouse callback re-entry

## Summary

`mouse_invoke_callback` in `src/kernel/mouse.inc` issues `call far [cs:mouse_callback_off]` from inside the IRQ12 path on whatever stack was current when the IRQ fired. The only re-entry guard is `mouse_in_callback`; there is no InDOS-style flag check, so a callback that itself issues `INT 21h` AH=3Fh/40h while the kernel is already running a read/write will corrupt the single-instance `rf_*`/`wf_*` scratch state in `src/kernel.asm`.

## Requirements

- Detect that a DOS call is in progress when the IRQ12 callback fires, and either defer the callback or refuse to invoke it.
- Preserve legitimate callback invocations from the top-level (no DOS call in flight) case.
- Add an InDOS counter or a similar small atomic flag that DOS callers increment on entry and decrement on exit.
- Make the deferred-callback path drain on the next safe point (e.g. when the kernel returns to a top-level user-mode context).

## Acceptance Criteria

- A regression installs a callback that issues `INT 21h` AH=3Fh from inside the mouse handler and verifies the kernel returns to a consistent state (no corrupted `rf_*` or `wf_*` fields, no leaked file position).
- A regression that calls the same callback from a non-DOS context still works.
- Existing mouse and DOS file I/O tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/mouse.inc:585-602` (`mouse_invoke_callback`), `src/kernel.asm` (rf_/wf_ scratch fields).
- The existing `mouse_in_callback` flag prevents re-entering the mouse code from inside a callback, but not re-entering the kernel from inside a callback.
- Discovered during a whole-system review on 2026-06-06.
