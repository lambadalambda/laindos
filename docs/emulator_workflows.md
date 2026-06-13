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
- If an old Borland Pascal program exits immediately with `Runtime error 200`, try QEMU `-icount shift=6` before debugging DOS or CD paths. The Sam & Max CD root `INSTALL.EXE` needs this timer mode under QEMU; plain QEMU, `-cpu 486`, and `-cpu pentium` still hit the runtime error.
- Use bare `-device sb16` for the generic game path. Add `-device adlib` only for games that need the separate OPL/AdLib probe path; Wolf3D's Sound Blaster startup line matches 86Box with `-device sb16 -device adlib`, and the Sam & Max CD launcher uses the pair so Sound Blaster setup also sees FM/OPL ports. The Monkey Island demo currently trips runtime error `R6003` with AdLib attached.
- `mise run-games-hd-all` therefore stays on bare `sb16`; use `mise run-wolf3d` when specifically checking Wolf3D's QEMU Sound Blaster detection path.
- Keep QEMU regression runs sequential when they share `build/`.
- Ascendancy needs the local QEMU `SAHF` fix unless your installed QEMU already includes it; see `docs/qemu-sahf-ccop.patch`.

## 86Box Workflow

Use 86Box when QEMU behavior looks suspect or when a game is known to like period-accurate hardware better.

Current repo convention:

- Keep an isolated VM profile under `build/86box-serial-file/`.
- Prefer copying that profile for one-off experiments instead of mutating the base VM.
- Keep COM1 on `stdio` so traces land in the terminal or log.
- `make test-cd-86box` builds a disposable generated-ISO profile under `build/cd_86box/profile/` and verifies LainDOS can mount an ATAPI CD-ROM as `D:` in 86Box.

Host paths that matter on macOS:

- 86Box executable: `/Applications/86Box.app/Contents/MacOS/86Box`
- Global 86Box config: `~/Library/Preferences/86Box/86box_global.cfg`
- VM manager index: `~/Library/Preferences/86Box/vmm.ini`
- User VM profiles: `~/Library/Application Support/86Box/Virtual Machines/<name>/86box.cfg`
- 86Box ROM bundle: `~/Library/Application Support/net.86box.86Box/roms/`

When locating existing VMs, read `~/Library/Application Support/86Box/Virtual Machines/` and `~/Library/Preferences/86Box/vmm.ini` directly. Do not glob the whole home directory; macOS protected directories produce noisy permission errors.

Disposable 86Box profile checklist:

- Put the profile under `build/<probe>/profile/` and write a fresh `86box.cfg` there.
- Do not copy `nvr/` unless you intentionally need an existing BIOS setup. Stale NVR can preserve boot order or disk geometry and make the BIOS boot the wrong disk; a `NoK` serial marker usually means the boot loader did not find `KERNEL.SYS`, not that the kernel or CD path failed.
- Before debugging a CD, run `python3 scripts/test_cd_86box.py --boot-only` or an equivalent floppy-only `HELLO.COM` profile. If boot-only fails, fix the 86Box profile first.
- Add `[Ports (COM & LPT)] serial1_device = stdio` and `[Virtual Console (COM) #1] mode = 0` so serial markers reach the test harness.
- Use `86Box -P <profile> -I a:/abs/path/to/floppy.img -N` for focused floppy probes. Absolute paths are easier to reason about, although 86Box may rewrite them relative to the profile after launch.

Useful command:

```sh
"/Applications/86Box.app/Contents/MacOS/86Box" \
  -P "/Users/lainsoykaf/repos/laindos/build/86box-serial-file" \
  -N
```

Current known-good graphics choice for Ascendancy:

- `gfxcard = s3_trio64_pci`

For CD-ROM tests, attach the ISO as an IDE ATAPI drive. LainDOS can mount through BIOS EDD, but CD path opens refresh the PVD/root/volume state through direct ATAPI when available and then keep subsequent directory/file reads on that validated transport. This avoids stale SeaBIOS sectors after a monitor media swap while still covering 86Box profiles whose BIOS does not expose non-boot CD media through `INT 13h AH=42h`.

For isolated CD tests, prefer the CD as IDE secondary master (`cdrom_01_ide_channel = 1:0`) and no hard disk. That keeps boot-order and hard-disk geometry out of the first discriminator. Once the floppy-only and generated-ISO probes pass, move back to the real profile shape, such as hard disk on `0:0` and CD on `0:1` for Sam & Max.

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

## Headless 86Box For Automated Tests

A headless, scriptable 86Box comes from the local 86Box checkout plus
`docs/86box-rpc.patch`, which adds an opt-in localhost HTTP RPC to the
SDL (non-Qt) frontend: `/status`, `/key?scan=<at-set-1>[&down=0|1]`,
`/screenshot`, `/monitor?cmd=<urlencoded>`, and `/exit`, enabled by the
`86BOX_RPC_PORT` environment variable (the patch also carries a
portable OpenAL include fix for macOS framework headers). Build it
with:

```sh
git clone --shared /path/to/86box build/86box
cd build/86box
git checkout -b laindos-rpc
git am ../../docs/86box-rpc.patch
cmake -B build-headless -DQT=OFF -DCMAKE_BUILD_TYPE=Release -DRTMIDI=OFF -DFLUIDSYNTH=OFF -DMUNT=OFF -DDISCORD=OFF
cmake --build build-headless -j 10
```

`scripts/box86lib.py` wraps the rest: it launches the binary with
`SDL_VIDEODRIVER=dummy` (no window) through `testlib.start_qemu`, so
serial output lands in the usual chunk readers, and provides RPC typing
helpers (AT set-1 scancodes), screenshot retrieval, and a pure-stdlib
PNG stats reader matching `ppm_stats`. The binary is found at
`build/86box/build-headless/src/86Box.app/Contents/MacOS/86Box` or via
`LAINDOS_86BOX_HEADLESS`; ROMs default to the installed app's set at
`~/Library/Application Support/net.86box.86Box/roms` or
`LAINDOS_86BOX_ROMS`.

Profile gotchas learned the hard way:

- With `serial1_device = stdio` the profile MUST also contain
  `[Virtual Console (COM) #1]` with `mode = 0`. Without it the char
  device defaults to its pseudoterminal mode, and the first guest
  serial byte spins forever in `char_stdio_write` against the
  reader-less PTY -- inside the emulator's timer processing, which
  holds the blit mutex, so the whole emulator (and the RPC
  `/screenshot` path behind `startblit()`) wedges.
- A fresh profile stops at the Award "CMOS checksum error / Press F1"
  prompt on first boot; send `/key?scan=0x3b` (F1) until the shell
  prompt appears (`box86lib` test flows do this in their boot loop).
- `make test-civ-86box` is the first consumer: it verifies Civilization
  reaches its title menu under 86Box -- the screen QEMU never reaches
  because of its PIT interaction with the game's INT 08 hook.
