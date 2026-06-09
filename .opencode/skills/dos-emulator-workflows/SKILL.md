---
name: dos-emulator-workflows
description: QEMU 86Box real DOS floppy file=fat:rw S3 Trio SB16 AdLib VNC monitor screendump. Use when debugging emulator-specific DOS behavior, comparing QEMU vs 86Box, booting real DOS in QEMU, or capturing serial/screenshot/CPU state from game runs.
---

# DOS Emulator Workflows

Use this skill when the task is about running or comparing LainDOS, real DOS, or DOS games under QEMU, 86Box, or Bochs.

## Primary Playbook

1. Start with QEMU for fast scripted runs.
2. If QEMU and 86Box diverge, first run a focused 86Box boot-only discriminator before changing DOS code.
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

Use bare `-device sb16` for the generic game path. Add `-device adlib` only for games that need the separate AdLib/OPL setup probe; Wolf3D needs it to match 86Box Sound Blaster detection, and the Sam & Max CD launcher needs it so the Sound Blaster setup path also sees FM/OPL ports. The Monkey Island demo currently trips runtime error `R6003` with AdLib attached. The all-games QEMU task intentionally stays SB16-only; use the dedicated Wolf3D or Sam & Max CD task when checking those sound-detection paths.

If an old Borland Pascal program exits immediately with `Runtime error 200`, try QEMU `-icount shift=6` before debugging DOS or CD paths. The Sam & Max CD root `INSTALL.EXE` needs this timer mode under QEMU; plain QEMU, `-cpu 486`, and `-cpu pentium` still hit the runtime error.

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

- 86Box executable on this host: `/Applications/86Box.app/Contents/MacOS/86Box`.
- Existing user VMs live under `~/Library/Application Support/86Box/Virtual Machines/`; read that directory and `~/Library/Preferences/86Box/vmm.ini` directly instead of globbing all of `~/`.
- Use the isolated VM profile under `build/86box-serial-file/` when it exists.
- Copy existing profiles only when you need their BIOS setup. For new probes, prefer a fresh disposable profile under `build/<probe>/profile/`.
- Do not copy `nvr/` by default. Stale NVR can preserve boot order/disk geometry and produce `NoK` by booting the wrong disk or failing to find `KERNEL.SYS` before your probe runs.
- Always add `[Ports (COM & LPT)] serial1_device = stdio` and `[Virtual Console (COM) #1] mode = 0` for automated probes.
- Ascendancy currently wants `gfxcard = s3_trio64_pci`.
- `cpu_use_dynarec = 0` and `fpu_softfloat = 1` are useful comparison toggles.
- For CD debugging, run `python3 scripts/test_cd_86box.py --boot-only` first. Then run `make test-cd-86box`. Use IDE secondary master (`cdrom_01_ide_channel = 1:0`) for isolated generated-ISO probes; move back to hard disk `0:0` plus CD `0:1` only after boot-only and generated-ISO checks pass.
- LainDOS CD reads try BIOS EDD first and direct ATAPI PIO fallback second. 86Box ATAPI profiles may not expose non-boot CD media through `INT 13h AH=42h`.

Launch command:

```sh
"/Applications/86Box.app/Contents/MacOS/86Box" -P "/Users/lainsoykaf/repos/laindos/build/86box-serial-file" -N
```

Focused floppy probe shape:

```sh
"/Applications/86Box.app/Contents/MacOS/86Box" \
  -P "/Users/lainsoykaf/repos/laindos/build/cd_86box/profile" \
  -I "a:/Users/lainsoykaf/repos/laindos/build/cd_86box/cd_86box.img" \
  -N
```

## Decision Rules

- If real DOS in QEMU reproduces the problem, de-prioritize LainDOS DOS/filesystem debugging for that issue.
- If 86Box progresses and QEMU does not, suspect QEMU hardware or CPU emulation.
- If the DOS trace stops but the CPU sample shows protected-mode code looping, treat DOS calls as the last visible boundary, not the actual cause.

## References

- `docs/emulator_workflows.md`
- `docs/debug_log.md`
