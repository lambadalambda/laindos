# Bring up the Simon the Sorcerer demo

## Summary

Boot the Simon the Sorcerer demo from `vendor/simon1demo.zip` under
LainDOS (AGOS engine, previously zero coverage), fix any faithful DOS
gaps, and add a vendor-gated smoke.

## Resolution (2026-06-11)

- `scripts/build_simon_hd.py` builds a bootable hd32m image with the
  demo in `C:\SIMON`; the bundled `SIMON.BAT` runs `RUNVGA GDEMO /3`.
- No kernel gaps: the AGOS engine boots straight to its interactive
  in-game forest scene — verb interface, inventory, and mouse cursor —
  in about 35 seconds on the faithful kernel. The only bring-up bug
  was in the new builder itself (hd10m is a FAT12 format while the
  boot sector was assembled with -DFAT16=1, so the first boot died
  with the boot sector's "NoK"; switched to hd32m).
- `scripts/test_simon_smoke.py` (vendor-gated, `make test-simon-smoke`)
  verifies the launch reaches the in-game scene (>=60 colors,
  >=150k nonblack pixels) with the BIOS tick advancing.
