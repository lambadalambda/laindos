# Emulator Workflows

Practical notes for running LainDOS, real DOS, and game payloads under QEMU, 86Box, and related tools.

## QEMU Baseline

Use QEMU first for fast, scriptable runs.

Tests and `make run` resolve QEMU in this order: `LAINDOS_QEMU`, the sibling patched build at `../qemu-ascendancy/build-asc/qemu-system-i386-unsigned`, then `qemu-system-i386` from `PATH`. `mise.toml` sets `LAINDOS_QEMU` to the patched local build.

For automated `make test` runs, prefer `make test` or the simpler `-monitor none -nographic` shape instead of the interactive monitor/VNC setup below.

Typical command shape:

```sh
"${LAINDOS_QEMU:-qemu-system-i386}" \
  -drive file=build/games_hd_all.img,format=raw \
  -boot order=c \
  -serial stdio \
  -monitor unix:/tmp/laindos.sock,server,nowait \
  -vga std,retrace=precise \
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

General rules:

- Use `-serial stdio` or a serial log for anything you want to diff or grep.
- Use a monitor socket plus `sendkey`/`screendump` for UI-driven tests.
- Hash screenshots when checking whether a screen is truly changing.
- Do not wait a long time blindly if CPU sampling can show the active loop quickly.
- Try short discriminator sweeps before deeper debugging: `-cpu ...`, `-vga ...`, sound on/off.
- Use `-vga std,retrace=precise` for QEMU game runs so VGA status polling loops, including Wolf3D's `0x3DA` startup loop, see retrace transitions.
- Keep QEMU regression runs sequential when they share `build/`.
- Ascendancy needs the local QEMU `SAHF` fix unless your installed QEMU already includes it; see `docs/qemu-sahf-ccop.patch`.

## 86Box Workflow

Use 86Box when QEMU behavior looks suspect or when a game is known to like period-accurate hardware better.

Current repo convention:

- Keep an isolated VM profile under `build/86box-serial-file/`.
- Prefer copying that profile for one-off experiments instead of mutating the base VM.
- Keep COM1 on `stdio` so traces land in the terminal or log.

Useful command:

```sh
"/Applications/86Box.app/Contents/MacOS/86Box" \
  -P "/Users/lainsoykaf/repos/laindos/build/86box-serial-file" \
  -N
```

Current known-good graphics choice for Ascendancy:

- `gfxcard = s3_trio64_pci`

Useful knobs when comparing emulator behavior:

- `cpu_use_dynarec = 0`
- `fpu_softfloat = 1`

If 86Box progresses and QEMU does not, strongly suspect QEMU rather than immediately changing LainDOS.

## Real DOS In QEMU

When you need to separate a LainDOS bug from a QEMU/game/runtime bug, boot a real DOS floppy in QEMU.

Fastest path found so far:

- Boot `build/DOS Boot Floppy.img` as floppy.
- Expose a host directory as a DOS drive using QEMU FAT export instead of hand-rolling partition images first.

Example:

```sh
"${LAINDOS_QEMU:-qemu-system-i386}" \
  -drive file="build/DOS Boot Floppy.img",format=raw,if=floppy \
  -drive file=fat:rw:/abs/path/to/build/realdos_asc,format=raw,if=ide \
  -boot order=a \
  -serial stdio \
  -monitor unix:/tmp/dos.sock,server,nowait \
  -vnc 127.0.0.1:51 \
  -device sb16
```

Notes:

- This gives real DOS a clean `C:` quickly.
- It is good enough for "does real DOS in QEMU reproduce this game/runtime bug?"
- It is not a substitute for a truly DOS-partitioned hard disk image when exact disk semantics matter.
- QEMU FAT export requires an absolute host path; relative paths silently fail.
- If the program requires a mouse, load `MOUSE.COM` from `AUTOEXEC.BAT` before launching it.

## Bochs Notes

Use Bochs when you need a second emulator implementation or more debugger-oriented CPU inspection than QEMU provides.

- Keep it focused on short reproductions.
- Use it to compare emulator behavior when QEMU and 86Box disagree.
- Prefer it for instruction-level and protected-mode sanity checks, not for broad regression sweeps.

## Building Truly DOS-Compatible FAT Images

If you really need a DOS-readable hard disk image, prefer real FAT tools over Python wrappers.

LainDOS also supports a minimal partitioned FAT16 hard-disk layout for regression and compatibility work:

- sector 0 is a tiny LainDOS MBR chainloader.
- partition 1 is active, type `06h`, and starts at LBA 63.
- the FAT16 partition boot sector contains the normal LainDOS FAT16 boot code.
- the BPB hidden-sector field must match the partition start, because boot and kernel sector I/O add that offset when reading FAT/root/data sectors.
- the FAT boot sector should use a conventional OEM string and volume label; MS-DOS mounted but misread an all-zero OEM/label test image.

The legacy `hd32m`/`hd96m` images remain raw FAT volumes with hidden sectors set to zero. Those are convenient for LainDOS/QEMU tests but are not the same as MS-DOS hard-disk images.

Current limits:

- The MBR and partition boot path use CHS `INT 13h`, so keep partitioned images below the 1024-cylinder CHS limit until an extended-read boot path exists.
- Some older filesystem call sites still carry only a 16-bit partition-relative sector number before reaching the common sector I/O offset logic. Keep directories and boot-critical files low in the partition for now.

Available host/container tools noted so far:

- host: `fdisk`, `qemu-img`, `newfs_msdos`, `diskutil`, `hdiutil`
- container path: `podman`

Guidance:

- Prefer native FAT tools or containerized Linux `dosfstools`/`mtools`.
- Avoid debugging CHS/MBR wrappers by hand unless the simpler tool path is blocked.
- For quick compatibility discrimination, QEMU FAT export is usually faster than building a full DOS disk from scratch.

## Interpreting Divergence

Use these heuristics:

- If 86Box and QEMU both fail the same way, keep looking at the guest/kernel.
- If 86Box progresses and QEMU stalls, suspect QEMU hardware or CPU emulation.
- If real DOS in QEMU reproduces the stall too, stop blaming LainDOS for that specific bug.
- If DOS trace stops but CPU sampling shows protected-mode math or graphics loops, the DOS API trace is only the last visible boundary, not the actual stall.

## Ascendancy-Specific Lessons

- The original slow-start issue on large FAT16 images was a real read-path bug in LainDOS and was fixed.
- After that fix, 86Box got past the Logic Factory screen quickly.
- Stock QEMU then stalled there, and real DOS in QEMU reproduced it too.
- Live QEMU sampling showed DOS/4GW x87 helper loops (`fprem`, then `fcos`/`fsin`), so the remaining issue was QEMU-side protected-mode CPU behavior rather than LainDOS DOS/file semantics.
- The root cause was QEMU i386 TCG `SAHF` lazy condition-code handling: `SAHF` updated `cpu_cc_src` but did not materialize `CC_OP_EFLAGS`, so the following `JNP` used stale parity state.
- The one-line fix is saved as `docs/qemu-sahf-ccop.patch` and committed in the sibling QEMU clone as `06cbfb3 target/i386: mark SAHF flags as materialized`.
- With that patched QEMU, Ascendancy reaches gameplay under LainDOS.
