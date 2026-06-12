# Bring up The Settlers II Gold Edition

## Summary

Get Die Siedler II Gold Edition (1996, German CD release) installing and
running on LainDOS. The vendor media is a CloneCD rip in
`vendor/die-siedler-2-gold/` (CD01.img, mixed mode: one MODE1/2352 data
track plus eight CD audio tracks). This is the heaviest target yet: a
Watcom/DOS4GW protected-mode game in 640x480 SVGA (VESA itself is already
exercised by Ascendancy) installing from CD-ROM.

## Requirements

- Extract the data track to an ISO and attach it as read-only `D:`
  alongside a writable LainDOS `C:` (the Sam & Max pattern).
- Drive the CD installer to an installed `C:` game.
- Launch the game and get as far as the kernel allows, fixing any
  DOS-faithfulness gaps it exposes (no per-title shims).

## Acceptance Criteria

- A vendor-gated smoke installs and launches the game headlessly,
  asserting a recognizable game screen and an advancing BIOS tick.
- Docs updated in lockstep (games.md section, status.md, README games
  list).

## Notes

- Source: https://archive.org/details/die-siedler-2-gold-edition
- Gold Edition = base game + mission CD content on one disc; German UI.
- Expect VESA (VBE) graphics, DOS/4GW, XMS/raw memory probing, and a CD
  presence check; Redbook audio tracks will not play (acceptable).

## Resolution (2026-06-12)

- The vendor-gated `make test-settlers2-smoke` installs from the CD data
  track through the real Blue Byte installer, reboots out of the
  post-install Setup menu (under QEMU no key moves its button focus and
  mouse clicks never fire — the same emulator interaction that stalls
  the game's menu input pump; under 86Box the keyboard works. The
  `-snapshot` overlay carries the installed `C:` across `system_reset`),
  launches the game, and asserts the 640x480 VESA main menu plus an
  advancing BIOS tick.
- The 86Box cross-check settled the input-pump question without the RPC
  mouse endpoint: under an interactive Pentium 75 VM (`p54tp4xe`, 16 MiB,
  S3 Trio32 PCI, PS/2 mouse, SB16, C: image on IDE 0:0 with 63/16/325
  geometry, ISO as ATAPI 1:0) the game is fully playable — user-confirmed
  in-game. The stall is QEMU-side, not a kernel gap.
- Docs updated in lockstep: games.md section, status.md bullet, README
  games list, debug log closure. The three kernel faithfulness fixes
  (arena top at INT 12h, DOS first fit, INT 33h driver info/state +
  cumulative mickeys) shipped earlier in commit 4a76d10.

## Progress (2026-06-12)

- Staged and installed end to end; the game runs through its 640x480 VESA
  splash to the full main menu. Three kernel faithfulness fixes came out
  of the trail (arena top at INT 12h, DOS first-fit restored, INT 33h
  driver info/state functions + cumulative callback mickeys) — see the
  debug log entry of the same date.
- Remaining blocker: the menu consumes no input. Mouse events verifiably
  reach the game's DOS/4GW callback and its INT 9 hook eats keystrokes,
  but the timer-driven event pump never processes them (the splash
  advances by timeout). Suspected QEMU PIT interaction of the
  Civilization class; next step is an 86Box cross-check, which needs a
  mouse-injection endpoint added to docs/86box-rpc.patch.
- Side issues parked: Miles digital-audio auto-detect reports "hardware
  not found" under QEMU SB16; SETUP writes [VESA] MODE_*=N because
  SeaBIOS builds the VBE mode list in volatile scratch RAM (era BIOSes
  kept it in ROM) — the game ignores those flags for its own 640x480
  mode, so this is cosmetic for the game itself.
