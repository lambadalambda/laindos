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
- FCB calls beyond `AH=29h` filename parsing.
- Full DOS swappable data area layout and `AH=5Dh` internal subfunctions beyond the minimal `AX=5D06h` compatibility header.
- Full Windows long-filename semantics beyond the `AH=71h` unsupported fallback signal.
- `AH=5Ch` sharing/locking semantics.
- `AH=5Eh/5Fh` network and redirector calls.
- `AH=65h/66h` NLS/code-page APIs and full country/DBCS tables.
- `CONFIG.SYS` and installable DOS device driver loading.
- Full TSR environment-block retention and XMS/EMS cleanup semantics beyond CWSDPMI-style startup.
