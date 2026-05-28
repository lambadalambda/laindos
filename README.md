# LainDOS

LainDOS is a tiny single-tasking DOS implementation for x86 real mode. Its original target was booting and running **The Secret of Monkey Island** (VGA, 1990); current work has expanded into a small DOS/game compatibility testbed for real-mode and DOS-extender-era games.

This is not a general-purpose FreeDOS replacement. It implements the DOS subset needed by the games and regression programs we actually run, while leaving BIOS, VGA, timer, keyboard, mouse hardware, and sound hardware mostly to the emulator or host PC model.

## Current Status

- Boots FAT12 floppy images, raw FAT hard-disk images, and a minimal partitioned FAT16 hard-disk layout.
- Loads `.COM` and MZ `.EXE` programs with PSP setup, relocation, terminate vectors, environment blocks, and MCB allocation.
- Provides a small shell with `AUTOEXEC.BAT`, current directory support, environment/PATH handling, and parent/child `EXEC` coverage.
- Implements the core DOS file APIs used by the current suite: open/read/write/seek/close, create/truncate, delete, rename, attributes, timestamps, disk free, FindFirst/FindNext, and writable FAT12/FAT16 paths.
- Provides a built-in `INT 33h` mouse service backed by PS/2 mouse packets, including movement/buttons, callbacks, scaling, and edge clamping.
- Provides minimal single-handle XMS APIs for game startup detection and backed XMS moves, using BIOS-reported extended memory capped at 15 MiB. Experimental backed EMS support exists behind `ENABLE_EMS=1` but is hidden in default builds.
- Runs the Monkey Island demo and full VGA Monkey Island images when the corresponding local `vendor/` archives are present.
- Runs Ascendancy under 86Box and under a locally patched QEMU with the `SAHF` condition-code fix documented in `docs/qemu-sahf-ccop.patch`.
- Runs Wolfenstein 3D shareware to visible first-level gameplay when `vendor/wolf3dsw.zip` is present.
- `make test` currently runs the automated QEMU regression ladder and passes `36/36` tests.

## Scope

LainDOS focuses on practical game compatibility rather than abstract DOS completeness.

Implemented or in active use:

- Real-mode boot, FAT filesystem access, and DOS API dispatch.
- FAT12, FAT16, raw HD images, and simple partitioned FAT16 images.
- DOS memory allocation through MCBs.
- Minimal XMS detection, query, single-block allocation, handle-release behavior, and XMS block moves.
- Basic device names and console I/O.
- Minimal shell, batch startup, and PATH lookup.
- Built-in mouse driver behavior for games that call `INT 33h` directly.

Still out of scope unless a target forces it:

- Full `COMMAND.COM` compatibility.
- Native DOS device driver loading or `CONFIG.SYS` processing.
- Full XMS multi-handle/reallocation/HMA behavior, full multi-handle EMS/named-handle behavior, UMB/HMA, load-high behavior, SHARE, redirectors, printing, or networking.
- Implementing sound hardware in DOS; games talk to emulator-provided hardware such as `-device sb16` directly.
- General DPMI/VCPI services. DOS extenders that manage protected mode themselves may work if their real-mode DOS calls and CPU assumptions are satisfied.

## Architecture

Single real-mode, non-reentrant, single-tasking kernel.

Current important segment layout:

```text
0000:0000  Interrupt Vector Table
0040:0000  BIOS Data Area
0060:0000  FAT scratch buffer
0340:0000  relocated kernel
0920:0000  sector buffer
0940:0000  default environment block
0960:0000  root directory buffer
0340:BC00  kernel stack top (physical 0F000)
1000:0000  start of MCB-managed program memory
A000:0000  VGA graphics memory
```

Disk I/O delegates to BIOS `INT 13h`. Filesystem and DOS API layers are intentionally small and case-insensitive for 8.3 names.

When built with `ENABLE_EMS=1`, the experimental EMS frame uses `9000:0000`. That frame is writable and backed, but it is not carved out of the DOS MCB arena; reserving 64 KiB there drops Wolfenstein 3D below its conventional-memory threshold, while leaving it unreserved can corrupt programs that also allocate that range. Default builds therefore hide EMS.

The low-memory layout is tight. See `src/memory.inc` and the compile-time assertions near the end of `src/kernel.asm` before moving buffers or adding large kernel features.

## Toolchain

- **Assembly:** NASM for boot sectors, kernel, tests, and real-mode utilities.
- **Emulation:** QEMU for fast scripted runs, 86Box for period-style game validation, Bochs for CPU/debugger cross-checks.
- **Optional C compiler:** Open Watcom is the intended 16-bit DOS C compiler if C test programs are added, but the current core is NASM assembly.
- **References:** Ralf Brown's Interrupt List, MS-DOS 4.00 source (MIT), and FreeDOS kernel behavior for conceptual comparison only. Do not copy GPL FreeDOS code.

## Build And Test

Default build and regression test:

```sh
make test
```

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
```

QEMU selection order for tests and `make run`:

```text
1. LAINDOS_QEMU if set
2. ../qemu-ascendancy/build-asc/qemu-system-i386-unsigned if it exists
3. qemu-system-i386 from PATH
```

`mise.toml` sets `LAINDOS_QEMU` to the local patched QEMU path. Stock QEMU can still run most regression tests, but Ascendancy needs the QEMU `SAHF` fix until that change exists upstream or in your installed QEMU.

## Game Images

Build the original Monkey Island demo image from loose files under `vendor/`:

```sh
python3 scripts/build_monkey.py
```

Build the full VGA Monkey Island hard-disk image from `vendor/monkey_full.zip`:

```sh
python3 scripts/build_monkey_full.py
```

Build the all-games image with Monkey Island, Monkey Island 2, Simon demo, Ascendancy, and Wolfenstein 3D shareware when the corresponding local archives are present:

```sh
python3 scripts/build_games_hd_all.py
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
3. **Filesystem image tests** cover FAT12/FAT16, large images, partitioned FAT16, corrupt FAT entries, high-LBA directories, and write durability.
4. **Game images** validate the behavior that motivated the DOS API work.
5. **Emulator cross-checks** use 86Box, Bochs, and real DOS in QEMU when QEMU behavior looks suspicious.

## Compatibility Notes

- `INT 21h AH=30h` returns DOS 3.30 by default because many era games prefer 3.x semantics.
- LainDOS uses serial output heavily. Use `-serial stdio` or a serial log for reproducible traces.
- If 86Box progresses but QEMU stalls, check `docs/emulator_workflows.md` and `docs/debug_log.md` before changing DOS behavior.
- The current local QEMU workaround is saved as `docs/qemu-sahf-ccop.patch` and is committed separately in the sibling QEMU clone as `06cbfb3 target/i386: mark SAHF flags as materialized`.

## Project Tracking

- Open work lives in `meta/issues.md` and detailed files under `meta/issues/`.
- Completed phases and compatibility fixes are archived in `meta/issues_archive.md`.
- Non-trivial investigations are recorded in `docs/debug_log.md`.
- `docs/gpt_handoff.md` is the original planning handoff. Treat it as historical background, not current status.

## License

LainDOS is released under the CC0 1.0 Universal public domain dedication. See `LICENSE`.
