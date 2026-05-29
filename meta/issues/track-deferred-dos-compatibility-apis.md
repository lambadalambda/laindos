# Track Deferred DOS Compatibility APIs

## Summary

Track DOS APIs that remain intentionally deferred after Phase 19 because no current game, installer, shell path, or regression requires full behavior.

## Requirements

- Keep deferred compatibility work caller-driven.
- Add a focused repro or game trace before implementing a deferred API.
- Prefer narrow local semantics over broad stubs that hide missing behavior.

## Acceptance Criteria

- A target program, installer, or regression demonstrates a concrete need before any item moves out of deferred status.
- New implementations include focused 16-bit coverage where feasible.
- Phase 19 remains archiveable without losing track of known deferred areas.

## Deferred Areas

- `AH=03h/04h/05h` AUX/PRN I/O policy.
- `AH=31h` TSR/keep-process behavior.
- FCB calls beyond `AH=29h` filename parsing.
- `AH=5Ch` sharing/locking semantics.
- `AH=5Eh/5Fh` network and redirector calls.
- `AH=38h/65h/66h` NLS and code page APIs.
- `CONFIG.SYS` and installable DOS device driver loading.
