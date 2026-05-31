---
name: dos-emulator-workflows
description: QEMU 86Box real DOS floppy file=fat:rw S3 Trio SB16 AdLib VNC monitor screendump. Use when debugging emulator-specific DOS behavior, comparing QEMU vs 86Box, booting real DOS in QEMU, or capturing serial/screenshot/CPU state from game runs.
---

# DOS Emulator Workflows

Use this skill when the task is about running or comparing LainDOS, real DOS, or DOS games under QEMU, 86Box, or Bochs.

## Primary Playbook

1. Start with QEMU for fast scripted runs.
2. If QEMU and 86Box diverge, compare against the isolated 86Box VM under `build/86box-serial-file/`.
3. If you need to rule LainDOS in or out, boot a real DOS floppy in QEMU and expose the game tree with `file=fat:rw:<hostdir>`.
4. Use CPU/screen sampling before long waits.

## Bochs Notes

If QEMU and 86Box disagree and you want a third emulator implementation or more debugger-oriented CPU inspection, use Bochs for a short focused reproduction.

## QEMU Recipes

Baseline game run:

```sh
qemu-system-i386 \
  -drive file=build/games_hd_all.img,format=raw \
  -boot order=c \
  -serial stdio \
  -monitor unix:/tmp/laindos.sock,server,nowait \
  -vnc 127.0.0.1:51 \
  -device sb16
```

Use bare `-device sb16` for the generic game path. Add `-device adlib` only for games that need the separate AdLib/OPL setup probe; Wolf3D needs it to match 86Box Sound Blaster detection, while the Monkey Island demo currently trips runtime error `R6003` with AdLib attached. The all-games QEMU task intentionally stays SB16-only; use the dedicated Wolf3D task when checking that sound-detection path.

Real DOS comparison run:

```sh
qemu-system-i386 \
  -drive file="build/DOS Boot Floppy.img",format=raw,if=floppy \
  -drive file=fat:rw:/abs/path/to/build/realdos_asc,format=raw,if=ide \
  -boot order=a \
  -serial stdio \
  -monitor unix:/tmp/dos.sock,server,nowait \
  -vnc 127.0.0.1:51 \
  -device sb16
```

Useful monitor commands:

```text
sendkey c
sendkey ret
screendump build/screen.ppm
info registers
x /12i $eip
xp /1dw 0x46c
quit
```

## 86Box Notes

- Use the isolated VM profile under `build/86box-serial-file/`.
- Copy it for experiments instead of mutating the main profile.
- Ascendancy currently wants `gfxcard = s3_trio64_pci`.
- `cpu_use_dynarec = 0` and `fpu_softfloat = 1` are useful comparison toggles.

Launch command:

```sh
"/Applications/86Box.app/Contents/MacOS/86Box" -P "/Users/lainsoykaf/repos/laindos/build/86box-serial-file" -N
```

## Decision Rules

- If real DOS in QEMU reproduces the problem, de-prioritize LainDOS DOS/filesystem debugging for that issue.
- If 86Box progresses and QEMU does not, suspect QEMU hardware or CPU emulation.
- If the DOS trace stops but the CPU sample shows protected-mode code looping, treat DOS calls as the last visible boundary, not the actual cause.

## References

- `docs/emulator_workflows.md`
- `docs/debug_log.md`
