# Cover IOCTL Edge Semantics

## Summary

Strengthen `INT 21h AH=44h` IOCTL coverage around unsupported subfunctions and invalid handle/drive failures.

## Requirements

- Supported file and device info/status queries keep their current compatibility behavior.
- Unsupported IOCTL subfunctions fail with function-number error `AX=0001h`.
- Invalid handle-based IOCTL calls fail with invalid-handle error `AX=0006h`.
- Invalid drive-based IOCTL calls fail with invalid-drive error `AX=000Fh`.

## Acceptance Criteria

- A focused 16-bit regression exercises unsupported subfunction, bad handle, and bad drive IOCTL paths under QEMU.
- Existing file/device/local/removable IOCTL coverage remains intact.
- `make test` passes.
- The Phase 19 matrix records the covered IOCTL edge semantics.
