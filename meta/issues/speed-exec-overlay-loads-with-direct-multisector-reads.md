# Speed EXEC and Overlay Loads with Direct Multi-Sector Reads

## Summary

Program and overlay loading still read through `SEC_BUF` one sector at a time and
copy into the destination. Speed up large EXEC and overlay loads by combining
safe multi-sector transfers with direct reads into the destination buffer where
possible.

## Requirements

- Measure generated EXEC/overlay-style load behavior before changing the loader.
- Avoid the `SEC_BUF` bounce copy for full-sector chunks that can be read directly into the destination.
- Split transfers at cluster boundaries, segment/64 KiB boundaries, and any BIOS transfer boundaries.
- Preserve relocation, overlay, partial-tail, and error semantics.

## Acceptance Criteria

- A generated benchmark shows lower BIOS call counts and reduced loader copy work for a large generated program or overlay image.
- Existing EXEC, overlay, relocation, shell, and game smoke tests continue to pass.
- Partial final sectors and unaligned overlay ranges still load byte-exactly.

## Notes

- Relevant paths include `load_file_direct` and overlay copy/load helpers.
- This should probably follow the generic multi-sector BIOS-read work so the loader can reuse the safe transfer-count logic.
