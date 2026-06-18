# Millennia Main-Game Digital Audio Silence

## Summary

Millennia setup PCM/MIDI and protected-mode intro PCM work, but automatic main-game digital SFX are silent after the intro. The issue is tabled because the game is otherwise usable enough for current bring-up, and the same silence reproduces under a real-DOS Win98 boot floppy plus JEMM386 path in QEMU.

## Requirements

- Preserve the current working paths: setup PCM/MIDI, intro PCM, main-game MIDI, CD file access, and main-game graphics.
- Do not spend further kernel work on this until there is a known-good control run or a clear user-visible action that should trigger SFX.

## Acceptance Criteria

- A known-good DOS/emulator control identifies a specific in-game action that should produce digital SFX, and LainDOS either matches it or has a narrowed failing API/hardware path.
- Alternatively, the issue is closed as out-of-scope if the silence remains reproducible under real DOS in the same setup and no game-critical SFX path is required.

## Notes

- Current evidence is summarized in `docs/debug_log.md` under `2026-06-17 Millennia Main-Game Digital Audio Silence`.
- QEMU SB16/DMA tracing showed the real-mode HMI driver starts auto-init DMA and IRQs continue, but the DMA buffer contains unsigned 8-bit silence (`0x80`).
- Real-DOS control used the official FreeDOS `jemm` package 5.84, verified by SHA1, with `JEMM386 LOAD` under `vendor/Windows 98 Second Edition Boot.img`.
