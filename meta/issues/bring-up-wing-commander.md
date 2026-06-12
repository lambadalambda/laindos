# Bring up Wing Commander

## Summary

Get Origin's Wing Commander (1990, "Version B2.4: HI 3.5" three-floppy
release) installing and running on LainDOS. The disks are in
`vendor/wing-commander_202104/disk1..3.ima`, with loose data files plus the
real `INSTALL.EXE` on disk 1. The game is famously demanding: large
conventional-memory footprint, optional EMS use, and a timing-sensitive
engine.

## Requirements

- Stage script that copies the vendor floppies and builds a blank bootable
  hard-disk target.
- Drive the genuine installer (with floppy swaps) to an installed `C:` game.
- Launch the game and get as far into it as the kernel allows, fixing any
  DOS-faithfulness gaps it exposes (no per-title shims).

## Acceptance Criteria

- A vendor-gated smoke (`make test-wc-smoke` or similar) installs and
  launches the game headlessly, asserting a recognizable game screen and an
  advancing BIOS tick.
- Docs updated in lockstep (games.md section, status.md, README games list).

## Notes

- Source: https://archive.org/download/wing-commander_202104 (3 x 1.44MB
  `.ima`).
- Disk 1 carries a `SYSTEM~1` ("System Volume Information") Windows leftover
  from imaging; ignore it.
- `WC.EXE` is ~305KB; check whether it is EXEPACK-packed (LOADFIX exists if
  the era bug appears).

## Resolution

- `WC.EXE` and `INSTALL.EXE` are plain MS C executables — no EXEPACK, no
  LOADFIX needed; the game also runs happily without EMS.
- The bring-up exposed one real DOS-faithfulness gap: the installer prompts
  for disk swaps while `A:` is the current drive, where lookups are served
  entirely from the cached FAT/root and the change-line error never
  surfaces. Implemented real DOS's MEDIA CHECK (`floppy_media_check` in
  `activate_drive`'s same-drive path, with the 2-second rule, and
  content-confirmation of QEMU's permanently-latched change line via a root
  sector compare). Pinned TDD-style by the extended
  `scripts/test_hdfloppy.py`.
- Game flow automated end to end in `scripts/test_wc_smoke.py`
  (`make test-wc-smoke`): real installer with two swaps ("Save Space" to
  skip the slow VGA expansion), Claw Marks quiz answered by reading the
  drawn question from guest RAM against the documented 19-entry answer
  table, mouse-steered click on Start Vega Campaign (ENTER aborts there),
  pilot name entry, ESC out of the simulator, and the animated bar scene
  with the BIOS tick advancing.
