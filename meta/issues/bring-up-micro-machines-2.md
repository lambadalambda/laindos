# Bring up Micro Machines 2

## Summary

Boot Micro Machines 2 from `vendor/003513_micro_machines_2.7z` under
LainDOS, fix the faithful DOS gaps it exposes, and add a vendor-gated
smoke.

## Resolution (2026-06-12)

- The archive holds four installer floppies whose game files live in
  `.SHR` bundles only the real Codemasters installer unpacks, so the
  bring-up had to run the genuine floppy installer — which exposed two
  real DOS-faithfulness gaps:
  - Hard-disk boots aliased `A:` (and `B:`) to the boot disk instead
    of the BIOS floppy. `mount_bios_floppy_a` now mounts BIOS drive
    00h as `A:` during hard-disk boot when a readable floppy is
    present, falling back to the old alias when there is none.
  - A floppy swap under an in-flight operation went unnoticed: the
    INT 13h retry loop swallowed the change-line error (AH=06h) and
    re-read the new disk with the old volume state.
    `floppy_media_remount` now hooks error 06h in the sector I/O
    loop: reset the drive, re-read the BPB, reload the active volume
    buffers, invalidate the FAT/read caches, reset `A:`'s working
    directory to root, and retry the I/O.
  - `scripts/test_hdfloppy.py` pins both (in DEFAULT_TESTS; suite now
    141): a file read from `A:` after a hard-disk boot, a file from
    the second disk after a monitor-driven swap, and the stale
    first-disk file correctly gone.
- With those in place the real installer runs end to end: language
  selection, destination, SHR unpacking with three prompted disk
  swaps, sound setup. The installed game launches through DOS/4GW
  1.97 to its interactive manual-symbol copy-protection screen
  (column/row lookup on the code card); going further needs the
  manual, so coverage stops there.
- `scripts/build_mm2_hd.py` stages the floppies and a blank bootable
  target; `scripts/test_mm2_smoke.py` (vendor-gated,
  `make test-mm2-smoke`) drives install, swaps, launch, the game
  screen, and an advancing BIOS tick.
