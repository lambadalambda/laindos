# Game Images

How to build, run, and smoke-test the game images LainDOS targets.

## Monkey Island Demo

Build the shell-boot Monkey Island demo floppy from the bundled demo files under `vendor/`:

```sh
make monkey-demo
```

The generated image is `build/shell_monkey.img`. Booting it starts the LainDOS shell at `A:\>`; run the demo with `midemo`.

The `nightly` GitHub release is updated after each successful push to `main` with `laindos-monkey-demo-nightly.zip`, containing the bootable demo floppy image and usage notes.

Build the older direct-boot Monkey Island demo image:

```sh
python3 scripts/build_monkey.py
```

The Monkey Island demo loose files are tracked under `vendor/`; other game archives and loose game files remain ignored and should be provided locally before running the full-game builders or smoke tests.

## Full Monkey Island and the All-Games Image

Build the full VGA Monkey Island hard-disk image from `vendor/monkey_full.zip`:

```sh
python3 scripts/build_monkey_full.py
```

Build the all-games image with Monkey Island, Monkey Island 2, Simon demo, Ascendancy, and Wolfenstein 3D shareware when the corresponding local archives are present:

```sh
python3 scripts/build_games_hd_all.py
```

The same `build/games_hd_all.img`, or a simple MBR-partitioned FAT12/FAT16 hard disk such as a FreeDOS VHD, can be attached as a second QEMU drive while booting `build/shell_monkey.img`; LainDOS keeps the shell on `A:` and exposes the attached hard disk as `C:` for commands such as `C:`, `CD \MI2`, and `MONKEY2`.

Run the all-games image through mise:

```sh
mise run run-games-hd-all
```

## FreeDOS VHD as C:

If `vendor/FreeDOS.VHD` is present locally, boot from `A:` with that VHD attached as `C:` using:

```sh
mise run run-freedos-vhd
```

Set `LAINDOS_FREEDOS_VHD=/path/to/FreeDOS.VHD` to use a different local VHD. The task runs QEMU with `-snapshot` so the VHD is not written back.

## Sam & Max Hit the Road (CD-ROM)

Boot a fresh writable `hd160m` LainDOS `C:` image with the Sam & Max Hit the Road CD data track attached as read-only `D:`:

```sh
mise run run-sammax-cd
```

The task extracts `vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip` into `build/sammax_cd/BG_GOLD_3_data.iso`, rebuilds `build/sammax_cd/sammax_c.img` by default, and starts QEMU with `-icount shift=6`, SB16, and AdLib enabled so the root installer avoids Borland Pascal `Runtime error 200` and the Sound Blaster path has FM/OPL ports. Set `LAINDOS_SAMMAX_ARCHIVE=/path/to/archive.zip` to use a different source zip, `LAINDOS_SAMMAX_REBUILD_C=0` to reuse an existing C: image, `LAINDOS_SAMMAX_C_IMG=/path/to/image.img` to choose a different scratch disk, `LAINDOS_SAMMAX_C_FORMAT=hd96m`/`hd160m` to choose the generated C: size, `LAINDOS_SAMMAX_QEMU_ARGS="..."` to replace the default extra QEMU arguments, or `LAINDOS_SAMMAX_QEMU_ARGS=` to disable them.

## Stunt Island

Build the bootable installer-media image from `vendor/002514_stunt_island.7z`:

```sh
python3 scripts/build_stunt_hd.py
```

The generated `build/stunt_hd.img` boots to the LainDOS shell with the six installer floppies' contents laid out for the Disney installer. Install once with writes persisting (run `INSTALL` at the prompt and press ENTER through the defaults; it produces `C:\STUNTISL`):

```sh
python3 scripts/run_stunt_island.py --no-launch --no-snapshot --no-current-kernel
```

After that, boot the installed image in a normal visible QEMU window and launch `STUNT` with:

```sh
mise run run-stunt-island
```

Set `LAINDOS_STUNT_IMAGE=/path/to/image.img` to use a different local Stunt image. The task rebuilds a shell-boot `KERNEL.SYS` from current source and patches it into `build/run_stunt_island_current.img`, leaving the source image unchanged; set `LAINDOS_STUNT_CURRENT_KERNEL=0` to boot the image as-is. The task uses QEMU `-snapshot` by default; set `LAINDOS_STUNT_SNAPSHOT=0` if you intentionally want writes to persist to the disposable runtime image. Set `LAINDOS_STUNT_VNC=127.0.0.1:58` only if you also want a VNC endpoint.

The vendor-gated smoke runs the whole pipeline headlessly — rebuild the installer image, drive the installer through its defaults, launch `STUNT`, and verify the game reaches its interactive startup prompt with the BIOS tick advancing:

```sh
make test-stunt-island-smoke
```

## Civilization

Build a bootable hard-disk image with Sid Meier's Civilization in `C:\CIV` from `vendor/sid-meiers-civilization-au.zip`:

```sh
python3 scripts/build_civ_hd.py
```

`CIV.EXE` is EXEPACK-compressed, and the unpacker corrupts itself ("Packed file is corrupt") when loaded below segment 1000h — the placement a lean DOS-in-HMA layout produces, exactly as on real MS-DOS 5. Launch it through the bundled `LOADFIX.COM`, the same answer DOS 5 shipped:

```text
C:\>CD CIV
C:\CIV>LOADFIX CIV
```

The vendor-gated smoke verifies both halves — the bare launch fails with the era message and the LOADFIX launch reaches the startup menus and an animating VGA intro:

```sh
make test-civ-smoke
```

Under QEMU the game later stalls at a MicroProse presentation card (or exits with `R6003 integer divide by 0`): its `INT 08` hook leaves the BIOS tick at a third rate, and the same behavior reproduces under FreeDOS on the same QEMU, so it is an emulator-timing interaction rather than a LainDOS issue. Under the headless 86Box build (`docs/emulator_workflows.md`) the same image runs through the intro to the title menu; that cross-check is automated:

```sh
make test-civ-86box
```

## External Hard-Disk Images

Smoke-test a local external hard-disk image without writing to it:

```sh
python3 scripts/test_attached_hd_shell.py /path/to/FreeDOS.VHD --format=vpc --expect=KERNEL.SYS
```

The script rebuilds `build/shell_monkey.img`, attaches the supplied image with QEMU `-snapshot`, switches to `C:`, runs `DIR`, and exits. It also accepts `LAINDOS_HD_IMAGE` and optional `LAINDOS_HD_FORMAT`; `.vhd` paths default to QEMU's `vpc` format and other paths default to `raw`.

The same smoke is available as `make test-attached-hd-shell` when `LAINDOS_HD_IMAGE` is set.

## Norton Commander

Norton Commander has startup, child-launch, file-copy, rename/delete, and mkdir/rmdir smokes when `vendor/003064_norton_commander.7z` is present. Run all of them with:

```sh
make test-norton-commander
```

Or run them individually:

```sh
make test-norton-commander-smoke
make test-norton-commander-launch
make test-norton-commander-copy
make test-norton-commander-rename-delete
make test-norton-commander-mkdir-rmdir
```

## Wolfenstein 3D

Build the experimental Wolfenstein 3D shareware image from `vendor/wolf3dsw.zip`:

```sh
python3 scripts/build_wolf3d.py
```

Wolfenstein 3D also has mise helpers:

```sh
mise run build-wolf3d
mise run run-wolf3d
```

Wolfenstein 3D needs QEMU's precise VGA retrace mode for the startup status-polling loop. Local QEMU run tasks default `LAINDOS_QEMU_VGA`/`QEMU_VGA` to `std,retrace=precise`; the default QEMU retrace path can leave it on a black screen even under real DOS.

## Mouse Testing

For interactive mouse testing, avoid `-nographic`; use a normal display, VNC, or the 86Box profile described in `docs/emulator_workflows.md`.
