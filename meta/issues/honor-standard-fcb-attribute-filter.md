# Honor standard FCB attribute filter

## Summary

`.fcb_find_first` in `src/kernel/int21.inc` hardcodes `ff_attr_mask = 0` for the non-extended (standard) FCB and only reads the attribute from `[ds:si+6]` when the FCB begins with `0xFF` (the extended-FCB signature). RBIL says the standard-FCB attribute filter lives at FCB+0x06, so any program using `AH=11h`/`AH=12h` with a non-zero attribute in a standard FCB gets a no-op filter that matches every entry.

## Requirements

- Read the standard-FCB attribute filter from `[ds:si+6]` and store it in `ff_attr_mask` for both extended and non-extended FCBs.
- Preserve the existing extended-FCB layout (`[ds:si+6]` attribute, with the `0xFF` signature marker at `[ds:si+0]`).
- Add focused regression coverage for both FCB forms with non-zero attribute filters (e.g. hidden-only, hidden+system+directory).

## Acceptance Criteria

- A regression creates a directory containing a normal file and a hidden file, runs `AH=11h` with a standard FCB whose attribute byte is `0x06` (hidden+system), and verifies only the hidden file matches.
- The same coverage runs against the extended-FCB form and still passes.
- Existing FCB and FindFirst tests still pass.
- `make test` passes.

## Notes

- Relevant code: `src/kernel/int21.inc:584-590` (`.fcb_find_first` attribute load).
- Discovered during a whole-system review on 2026-06-06; Civilization and other FCB-based tools may rely on this.
- Closed as invalid on 2026-06-07. A standard FCB stores `drive + 8-byte name + 3-byte extension`, so standard FCB byte `+6` is part of the filename, not an attribute filter. The attribute byte at extended-FCB `+6` exists only when the FCB starts with `0xFF`; the embedded standard FCB then begins at `+7`. Existing `tests/programs/fcbfind.asm` already verifies that a standard FCB named `FCBDIR` does not match a directory, while an extended FCB with attribute `0x10` does.
