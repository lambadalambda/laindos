# Investigate Civilization's QEMU PIT stall

## Summary

After `LOADFIX CIV` reaches the menus and intro, Civilization stalls at
the "A MICROPROSE PRESENTATION" card under QEMU and either hangs there
indefinitely (stock QEMU) or exits with `run-time error R6003 -
integer divide by 0` after ~90 seconds (local SAHF-patched QEMU).
Evidence gathered on 2026-06-11:

- The game hooks `INT 08` directly (IVT vector pointed into the
  LOADFIX'd child segment) and after the hook installs, the BIOS tick
  at `0040:006C` advances at almost exactly one third of 18.2/s —
  consistent with a handler that chains the BIOS every third tick while
  the expected PIT speed-up never takes effect, so game-internal time
  runs 3x slow.
- During the card hold, QEMU's PIC shows `isr=01` (timer in service)
  with the CPU halted and IF=1.
- The behavior is OS-independent: FreeDOS 1.4 on the same QEMU (virtual
  FAT drive) dies with the identical R6003 at the same card, with the
  BIOS tick fully frozen there. It is therefore an emulator-timing
  interaction, not a LainDOS DOS-semantics gap.
- `-icount shift=6` (the Shortline/Borland fix) does not change the
  outcome; neither does the sound mode (No sounds vs AdLib/SB with
  QEMU `sb16`+`adlib` devices attached).

## Requirements

- Verify the same image under 86Box with a period 386/486 profile (the
  project's standard cross-check for QEMU timing artifacts); record
  whether the card advances to the main menu there.
- If 86Box progresses, characterize what QEMU's PIT/PIC delivery does
  differently around the game's INT 08 hook (the MI2 tick-batching
  notes in docs/debug_log.md are the starting point), and decide
  whether a QEMU-side patch (like the SAHF one) is warranted.

## Acceptance Criteria

- The stall has a pinned root cause class with an emulator comparison,
  and either a workaround documented in docs/games.md or a QEMU patch
  recorded like docs/qemu-sahf-ccop.patch.

## Resolution (2026-06-11)

- The 86Box cross-check is conclusive: on the headless RPC build
  (docs/86box-rpc.patch, SDL frontend, dummy video) with the same
  generated image and the same `LOADFIX CIV` launch, the game runs
  through the menus and intro to the interactive title menu ("Start a
  New Game / Load a Saved Game / EARTH / ..."), held stable with no
  R6003. The stall class is pinned: a QEMU PIT/INT 08 delivery
  interaction, not LainDOS and not the game per se.
- The workaround is documented in docs/games.md (run Civilization
  under the headless 86Box; `make test-civ-86box` automates the
  cross-check). A QEMU-side fix in the SAHF-patch style remains
  possible future work, with the MI2 tick-batching notes in
  docs/debug_log.md as the starting point, but is not needed for the
  game library.
