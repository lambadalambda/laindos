# Cover AH=4Dh Return Code Edge Cases

## Summary

`INT 21h AH=4Dh` reports the last child return code and clears it after retrieval. Add focused coverage for the one-shot read behavior, failed `EXEC` paths, and the no-child-yet state.

## Requirements

- `AH=4Dh` before any child return is pending should report normal zero status.
- Reading a child return code through `AH=4Dh` should clear it so a second read reports zero.
- Failed `AX=4B00h` `EXEC` calls should not create or overwrite a child return code.
- A failed `EXEC` should preserve a pending unread child return code.
- Keep `AH` as normal termination type zero for the currently supported termination paths.
- Update the Phase 19 compatibility matrix status for `AH=4Dh` if behavior changes.

## Acceptance Criteria

- A focused regression covers initial reads, nonzero child return codes, repeated reads, and failed `EXEC` preservation.
- Existing EXEC, shell, environment, and register-preservation tests pass.
- `make test` passes.

## Notes

- Termination types other than normal exit remain out of this focused slice until a caller needs Ctrl-C, critical-error, or TSR return classification.
