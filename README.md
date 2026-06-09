# LainDOS

LainDOS is a tiny single-tasking DOS implementation for x86 real mode. Its original target was booting and running **The Secret of Monkey Island** (VGA, 1990); current work has expanded into a small DOS/game compatibility testbed for real-mode and DOS-extender-era games.

This is not a general-purpose FreeDOS replacement. It implements the DOS subset needed by the games and regression programs we actually run, while leaving BIOS, VGA, timer, keyboard, mouse hardware, and sound hardware mostly to the emulator or host PC model.

## Current Status

- Boots FAT12 floppy images, raw FAT hard-disk images, simple MBR-partitioned FAT12/FAT16 hard disks, and floppy boots with an attached raw or partitioned FAT hard disk exposed as `C:`.
- Loads `.COM` and MZ `.EXE` programs with PSP setup, relocation, terminate vectors, environment blocks, and MCB allocation.
- Provides a small shell with `AUTOEXEC.BAT`, current directory support, environment/PATH/BLASTER handling, and parent/child `EXEC` coverage including inherited child PSP handle tables.
- Implements the core DOS file APIs used by the current suite: open/read/write/seek/close, create/truncate, delete, rename, attributes, timestamps, disk free, FindFirst/FindNext, and writable FAT12/FAT16 paths.
- Mounts a BIOS-visible ISO-9660 CD-ROM as read-only `D:` for file open/read through subdirectories, root `FindFirst`/`FindNext`, and minimal MSCDEX detection coverage.
- Provides a built-in `INT 33h` mouse service backed by PS/2 mouse packets, including movement, button press/release queries, callbacks, scaling, and edge clamping.
- Provides minimal single-handle XMS APIs for game startup detection and backed XMS moves, using BIOS-reported extended memory capped at 15 MiB. Experimental backed EMS support exists behind `ENABLE_EMS=1` but is hidden in default builds.
- Builds and runs the bundled shell-boot Monkey Island demo floppy.
- Runs the full VGA Monkey Island image when `vendor/monkey_full.zip` is present.
- Runs Ascendancy under 86Box and under a locally patched QEMU with the `SAHF` condition-code fix documented in `docs/qemu-sahf-ccop.patch`.
- Runs Wolfenstein 3D shareware to visible first-level gameplay when `vendor/wolf3dsw.zip` is present.
- `make test` currently runs the automated QEMU regression ladder and passes `95/95` tests.

## Scope

LainDOS focuses on practical game compatibility rather than abstract DOS completeness.

Implemented or in active use:

- Real-mode boot, FAT filesystem access, and DOS API dispatch.
- FAT12, FAT16, raw HD images, and simple MBR-partitioned FAT12/FAT16 images.
- DOS memory allocation through MCBs.
- Minimal XMS detection, query, single-block allocation, handle-release behavior, and XMS block moves.
- Basic device names and console I/O.
- Minimal shell, batch startup, and PATH lookup.
- Built-in mouse driver behavior for games that call `INT 33h` directly.

Still out of scope unless a target forces it:

- Full `COMMAND.COM` compatibility.
- Native DOS device driver loading or `CONFIG.SYS` processing.
- Full XMS multi-handle/reallocation/HMA behavior, full multi-handle EMS/named-handle behavior, UMB/HMA, load-high behavior, SHARE, redirectors, printing, or networking.
- Implementing sound hardware in DOS; games talk to emulator-provided hardware such as `-device sb16` directly, with `-device adlib` added only for games that need a separate OPL/AdLib probe path such as Wolf3D. LainDOS supplies a conventional `BLASTER=A220 I5 D1 H5 P330 T6` environment variable so games can find the Sound Blaster-compatible device.
- General DPMI/VCPI services. DOS extenders that manage protected mode themselves may work if their real-mode DOS calls and CPU assumptions are satisfied.

## Architecture

Single real-mode, non-reentrant, single-tasking kernel.

Current important segment layout:

```text
0000:0000  Interrupt Vector Table
0040:0000  BIOS Data Area
0060:0000  FAT scratch buffer
0200:0000  CD-ROM scratch buffer
0280:0000  relocated kernel
0B00:0000  sector buffer
0B20:0000  read cache buffer
0B40:0000  root directory buffer
0280:D400  kernel stack top (physical 0FC00)
1000:0000  start of MCB-managed program and environment memory
A000:0000  VGA graphics memory
```

Disk I/O delegates to BIOS `INT 13h`. Filesystem and DOS API layers are intentionally small and case-insensitive for 8.3 names.

When built with `ENABLE_EMS=1`, the experimental EMS frame uses `9000:0000`. That frame is writable and backed, but it is not carved out of the DOS MCB arena; reserving 64 KiB there drops Wolfenstein 3D below its conventional-memory threshold, while leaving it unreserved can corrupt programs that also allocate that range. Default builds therefore hide EMS.

The low-memory layout is tight. See `src/memory.inc` and the compile-time assertions near the end of `src/kernel.asm` before moving buffers or adding large kernel features.

## CPU Target

LainDOS targets 386-compatible real-mode execution. The boot sectors and kernel rely on 386+ instructions such as `movzx`, `pusha`/`popa`, and 32-bit operand forms, and the game and DOS-extender compatibility targets (Ascendancy, Wolf3D, Stunt Island, Civilization, etc.) all assume at least a 386 host. Pre-386 support (8086/286) is intentionally out of scope unless a future target forces it. QEMU `i386` and 86Box with a 386+ CPU profile are the default validation targets; do not replace 386+ instructions with 8086-safe sequences purely for compatibility.

## Toolchain

- **Assembly:** NASM for boot sectors, kernel, tests, and real-mode utilities.
- **Emulation:** QEMU for fast scripted runs, 86Box for period-style game validation, Bochs for CPU/debugger cross-checks.
- **Optional C compiler:** Open Watcom is the intended 16-bit DOS C compiler if C test programs are added, but the current core is NASM assembly.
- **References:** Ralf Brown's Interrupt List, MS-DOS 4.00 source (MIT), and FreeDOS kernel behavior for conceptual comparison only. Do not copy GPL FreeDOS code.

## Source Layout

- `src/` contains boot sectors, the kernel, kernel includes, and shared memory constants.
- `programs/` contains DOS utilities shipped on test/game images, such as the shell, memory-report tool, and `TIME.COM`.
- `tests/programs/` contains small NASM DOS regression programs and test boot helpers.
- `scripts/` contains image builders, host-side generators, and Python/QEMU test runners.

## Build And Test

Default build and regression test:

```sh
make test
```

For shell commands and `A:\>` examples, see the `Shell / Batch / PATH` track in `docs/site/`. For the test-writing workflow, see `docs/test_ladder.md` or the `Tests` track.

Check that docs/site source excerpts, documented Makefile targets, file references, and hardcoded test counts still match the tree:

```sh
make check-docs-sync
```

`make test` runs this documentation sync check before the QEMU regression ladder, so CI catches stale excerpts and command references on pushes.

Build the shell-boot Monkey Island demo floppy image:

```sh
make monkey-demo
```

Build the package published by the `nightly` GitHub release:

```sh
make nightly-package
```

Run the Monkey Island demo floppy in QEMU:

```sh
make run-monkey-demo
```

Headless smoke-test the shell-launched Monkey Island demo:

```sh
make test-monkey-demo
```

Game smoke tests keep the emulated SB16 device when a game expects it, and Wolf3D also adds QEMU's separate AdLib device. Automated runs route those devices to QEMU's `none` audio backend so tests stay silent.

Build and boot the local extras hard-disk image, which combines local archives that are not part of `vendor/FreeDOS.VHD` into `build/extras_hd.img`:

```sh
make extras-hd
make run-extras-hd
```

The extras image includes the existing all-games set plus Norton Commander, Civilization, and the Stunt Island installer source media. Stunt Island's installed `C:\STUNTISL` tree is still generated by running `INSTALL` from the image root.

Headless smoke-test Norton Commander 5.5 from the local archive:

```sh
make test-norton-commander-smoke
```

Headless smoke-test Shortline from `vendor/SHRTLINE.zip`:

```sh
make test-shortline-smoke
```

The Shortline smoke uses QEMU `-icount shift=6` because the game calibrates a private PIT/`INT 08h` timer loop too quickly under normal unthrottled QEMU and exits through its divide-by-zero handler before gameplay.

Serial fallback:

```sh
make test-serial
```

Mise tasks are available for common workflows:

```sh
mise run build
mise run test
mise run run
mise run build-games-hd-all
mise run run-games-hd-all
mise run build-extras-hd
mise run run-extras-hd
mise run run-freedos-vhd
mise run build-monkey-demo
mise run test-monkey-demo
```

QEMU selection order for tests and `make run`:

```text
1. LAINDOS_QEMU if set
2. ../qemu-ascendancy/build-asc/qemu-system-i386-unsigned if it exists
3. qemu-system-i386 from PATH
```

`mise.toml` sets `LAINDOS_QEMU` to the local patched QEMU path. Stock QEMU can still run most regression tests, but Ascendancy needs the QEMU `SAHF` fix until that change exists upstream or in your installed QEMU.

## Game Images

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

Build the full VGA Monkey Island hard-disk image from `vendor/monkey_full.zip`:

```sh
python3 scripts/build_monkey_full.py
```

Build the all-games image with Monkey Island, Monkey Island 2, Simon demo, Ascendancy, and Wolfenstein 3D shareware when the corresponding local archives are present:

```sh
python3 scripts/build_games_hd_all.py
```

The same `build/games_hd_all.img`, or a simple MBR-partitioned FAT12/FAT16 hard disk such as a FreeDOS VHD, can be attached as a second QEMU drive while booting `build/shell_monkey.img`; LainDOS keeps the shell on `A:` and exposes the attached hard disk as `C:` for commands such as `C:`, `CD \MI2`, and `MONKEY2`.

If `vendor/FreeDOS.VHD` is present locally, boot from `A:` with that VHD attached as `C:` using:

```sh
mise run run-freedos-vhd
```

Set `LAINDOS_FREEDOS_VHD=/path/to/FreeDOS.VHD` to use a different local VHD. The task runs QEMU with `-snapshot` so the VHD is not written back.

If the local generated Stunt Island image exists at `build/stunt_xmsfix_hd.img`, boot it in a normal visible QEMU window and launch `STUNT` using:

```sh
mise run run-stunt-island
```

Set `LAINDOS_STUNT_IMAGE=/path/to/image.img` to use a different local Stunt image. The task rebuilds a shell-boot `KERNEL.SYS` from current source and patches it into `build/run_stunt_island_current.img`, leaving the source image unchanged; set `LAINDOS_STUNT_CURRENT_KERNEL=0` to boot the image as-is. The task uses QEMU `-snapshot` by default; set `LAINDOS_STUNT_SNAPSHOT=0` if you intentionally want writes to persist to the disposable runtime image. Set `LAINDOS_STUNT_VNC=127.0.0.1:58` only if you also want a VNC endpoint.

Smoke-test a local external hard-disk image without writing to it:

```sh
python3 scripts/test_attached_hd_shell.py /path/to/FreeDOS.VHD --format=vpc --expect=KERNEL.SYS
```

The script rebuilds `build/shell_monkey.img`, attaches the supplied image with QEMU `-snapshot`, switches to `C:`, runs `DIR`, and exits. It also accepts `LAINDOS_HD_IMAGE` and optional `LAINDOS_HD_FORMAT`; `.vhd` paths default to QEMU's `vpc` format and other paths default to `raw`.

The same smoke is available as `make test-attached-hd-shell` when `LAINDOS_HD_IMAGE` is set.

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

Build the experimental Wolfenstein 3D shareware image from `vendor/wolf3dsw.zip`:

```sh
python3 scripts/build_wolf3d.py
```

Run the all-games image through mise:

```sh
mise run run-games-hd-all
```

Wolfenstein 3D also has mise helpers:

```sh
mise run build-wolf3d
mise run run-wolf3d
```

Wolfenstein 3D needs QEMU's precise VGA retrace mode for the startup status-polling loop. Local QEMU run tasks default `LAINDOS_QEMU_VGA`/`QEMU_VGA` to `std,retrace=precise`; the default QEMU retrace path can leave it on a black screen even under real DOS.

For interactive mouse testing, avoid `-nographic`; use a normal display, VNC, or the 86Box profile described in `docs/emulator_workflows.md`.

## Test Strategy

1. **Tiny DOS programs** exercise one API surface at a time under QEMU.
2. **Shell and utility tests** cover command dispatch, file I/O, environment/PATH, device names, memory reports, and directory mutation.
3. **Filesystem image tests** cover FAT12/FAT16, large images, partitioned FAT16, attached partitioned `C:` volumes, corrupt FAT entries, high-LBA directories, and write durability.
4. **Game images** validate the behavior that motivated the DOS API work.
5. **Emulator cross-checks** use 86Box, Bochs, and real DOS in QEMU when QEMU behavior looks suspicious.

## Compatibility Notes

- `INT 21h AH=30h` returns DOS 3.30 by default because many era games prefer 3.x semantics.
- LainDOS uses serial output heavily. Use `-serial stdio` or a serial log for reproducible traces.
- If 86Box progresses but QEMU stalls, check `docs/emulator_workflows.md` and `docs/debug_log.md` before changing DOS behavior.
- The current local QEMU workaround is saved as `docs/qemu-sahf-ccop.patch` and is committed separately in the sibling QEMU clone as `06cbfb3 target/i386: mark SAHF flags as materialized`.

## Interactive Documentation

`docs/site/` contains source for the browser documentation with an embedded v86 emulator that runs `shell_monkey.img` in-page. `make site` pre-renders real static pages into `build/site/` (`index.html`, `boot.html`, `dosapi.html`, `tests.html`, `filesystem.html`, `memory.html`, `programs.html`, `shell.html`, `mouse.html`, and `run.html`) and compiles the JSX into one `app.js`, so production loads do not rely on browser-side Babel. The site currently includes the boot-path walkthrough, an end-user `INT 21h` compatibility guide, the regression test ladder, filesystem/FAT and memory/MCB tracks, a program-loading track, shell/batch/PATH docs, and mouse/INT 33h docs. The `.github/workflows/pages.yml` workflow builds the disk image (`make monkey-demo`), builds the static site with image cache-busting (`make site SITE_IMAGE=build/shell_monkey.img`), verifies the generated files, and publishes them to GitHub Pages on every push to `main`. To enable: in the repository's *Settings -> Pages*, set **Source** to **GitHub Actions**.

## Project Tracking

- Open work lives in `meta/issues.md` and detailed files under `meta/issues/`.
- Completed phases and compatibility fixes are archived in `meta/issues_archive.md`.
- Non-trivial investigations are recorded in `docs/debug_log.md`.
- `docs/gpt_handoff.md` is the original planning handoff. Treat it as historical background, not current status.

## License

LainDOS is released under the CC0 1.0 Universal public domain dedication. See `LICENSE`.
