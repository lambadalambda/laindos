# Bring up Command & Conquer: Red Alert (DOS)

## Summary

Get the DOS version of Red Alert (Westwood, 1996) installing from its CD
and running on LainDOS. EA released the full two-CD set as freeware in
2008 (and GPLv3'd the engine source in 2020); the vendor media is the
freeware Allied/Soviet ISOs in `vendor/cnc-red-alert/`. This stacks most
of the recent kernel work: DOS/4GW protected mode, CD-ROM file access
under sustained load, INT 33h mouse, and (for the SVGA mode) VESA.

## Requirements

- Stage a writable LainDOS `C:` with the Allied ISO attached as `D:`
  (plain ISO9660 data discs — no cue/bin extraction needed).
- Drive the DOS installer (`INSTALL.EXE`) to an installed `C:` game.
- Launch the installed game and fix any DOS-faithfulness gaps it
  exposes (no per-title shims).

## Acceptance Criteria

- A vendor-gated smoke installs and launches the game headlessly,
  asserting a recognizable game screen and an advancing BIOS tick.
- Docs updated in lockstep (games.md section, status.md, README games
  list).

## Notes

- Source: https://archive.org/details/cnc-red-alert (EA freeware ISOs).
- Music is file-based (AUD in MIX archives), not Redbook — this title
  exercises CD data reads, not the audio path.
- The DOS executable supports 640x480 VESA in addition to 320x200 VGA.
- Mouse-driven menus: expect the QEMU input-dispatch stall (Civilization
  class) to limit QEMU to menu assertions, with 86Box as the playable
  target — plan an 86Box profile like the Settlers II one.
- Disc swaps: the Allied disc carries the install; the Soviet disc is
  for the Soviet campaign (runtime disc selection, not install-time).

## Progress

- Installer black screen: share-bits handle leak, fixed (`test_cd_share`,
  debug log "The Share-Bits Handle Leak").
- Post-launch "hang with constant HD read" (QEMU): the game was sitting
  at its insert-CD dialog — `Get_CD_Index()` reads the CD volume label
  via an exclusive-`_A_VOLID` FindFirst on `D:\` and matches it against
  "CD1"/"CD2". Fixed by serving the ISO9660 PVD volume id the way MSCDEX
  does (`test_cd_volid`, debug log "The 'Hang' That Was A Dialog").
  Verified under QEMU: the Allied disc identifies and the intro movie
  streams from the CD.
- Post-launch "hang on the DOS/4GW screen with constant HD writes"
  (86Box-only, surfaced because 86Box runs the disk at real PIO speed):
  DOS/4GW reserves a 16 MB swap by writing one byte past EOF. The write
  path zero-filled the whole gap one sector at a time, and FAT16 was
  write-through (both copies per entry) — ~64K sector I/Os. Fixed in two
  parts: gap extend now allocates clusters only (no zero-fill), and FAT16
  got a write-back window like FAT12. Swap reservation went from ~250 s
  to <19 s on 86Box; intro on screen by ~40 s (`test_gap_write`, debug
  log "The DOS/4GW 'Hang' Was A 16 MB Swap").
- Known wrinkle (user report, 86Box): the installer finishes but cannot
  be quit from its end screen — needed a reboot. Same family as the
  Settlers II post-install menu; revisit once the game itself is
  confirmed playable.
- Still open: user confirmation of menu/gameplay under 86Box, then the
  vendor-gated smoke and docs per acceptance criteria.
