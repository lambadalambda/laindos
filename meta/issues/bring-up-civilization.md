# Bring up Sid Meier's Civilization

## Summary

Boot Civilization from `vendor/sid-meiers-civilization-au.zip` under
LainDOS, fix the faithful DOS gaps it exposes, and add a vendor-gated
smoke.

## Resolution (2026-06-11)

- `scripts/build_civ_hd.py` builds a bootable hd32m image with the
  game files flattened into `C:\CIV` (the vendor zip holds the era
  floppy images; the extras builder's FAT extractor is reused).
- A bare `CIV` launch fails with "Packed file is corrupt": CIV.EXE is
  EXEPACK-compressed and the unpacker corrupts itself below segment
  1000h. With the arena base at 0x0B00 this placement is faithful —
  real MS-DOS 5 in the HMA produced the same failure, and shipped
  LOADFIX.COM for it. A probe kernel with the arena at 0x1000
  confirmed the diagnosis (game starts normally there).
- `programs/loadfix.asm` implements LOADFIX: it absorbs the free
  conventional memory below segment 1000h with one-paragraph probes
  grown to fill each gap (one-paragraph requests stay on the first-fit
  path; 2..SMALL_ALLOC_HIGH_MAX-paragraph requests are biased high),
  EXECs the target (.COM/.EXE appended for extensionless names) with
  the rest of the command tail forwarded, and passes the child's exit
  code through. The pad blocks free automatically at termination.
  `scripts/test_loadfix.py` pins it: bare child PSP below 64 KiB,
  LOADFIX child at/above it, tail forwarded, error exit codes set. It
  failed before the implementation existed and passes after.
- With `LOADFIX CIV` the game reaches its graphics/sound/input menus
  and the animating VGA intro under QEMU. `scripts/test_civ_smoke.py`
  (vendor-gated, `make test-civ-smoke`) verifies the era failure
  message, the menus, the animating intro, and an advancing BIOS tick.
- Further progress under QEMU is blocked by an emulator PIT
  interaction, not a LainDOS gap: see
  [investigate-civilization-qemu-pit-stall](investigate-civilization-qemu-pit-stall.md).
- `LOADFIX.COM` ships on the Civilization and extras images; the
  extras README now says `LOADFIX CIV`.
