# Fix INT 21h IOCTL Register Preservation

## Summary

`INT 21h AH=44h AL=00h` computes handle-table offsets with `CX` as a scratch register and can return with caller `CX` clobbered. The documented output for IOCTL get-device-info is `DX`, so `CX` should be preserved.

## Requirements

- Preserve caller `CX` for `AH=44h AL=00h` on file-handle, device-handle, and invalid-handle paths that reach the handle-table offset calculation.
- Keep the existing `DX` device-info return behavior for stdio, DOS device handles, and disk files.
- Add focused register-preservation coverage for IOCTL get-device-info.

## Acceptance Criteria

- A regression opens a real file, sets a sentinel `CX`, calls `AX=4400h`, and verifies `CX` survives while `DX` contains device info.
- The regression also covers at least one error or device/stdio path where practical.
- `python3 scripts/test_regpres.py` or the relevant focused test passes.
- `make test` passes.

## Notes

- Advisor audit identified `src/kernel.asm` around the `ioctl_get` handle offset calculation as using `mov cx, HANDLE_SIZE` / `mul cx` without preserving caller `CX`.
- This is a specific implemented-handler clobber, not a broad missing IOCTL subfunction request.
