# Architecture

Single real-mode, non-reentrant, single-tasking kernel.

## Memory Layout

Current important segment layout:

```text
0000:0000  Interrupt Vector Table
0040:0000  BIOS Data Area
0060:0000  FAT scratch buffer
0180:0000  CD-ROM scratch buffer
0200:0000  sector buffer
0220:0000  four-sector read cache buffer
02A0:0000  root directory buffer
06A0:0000  write cache buffer
06C0:0000  CD file-read cache buffers
0B00:0000  start of MCB-managed program and environment memory
A000:0000  VGA graphics memory
FFFF:0010  relocated kernel in the HMA (A20 enabled at boot)
FFFF:FFF0  kernel stack top
```

Disk I/O delegates to BIOS `INT 13h`. Filesystem and DOS API layers are intentionally small and case-insensitive for 8.3 names.

When built with `ENABLE_EMS=1`, the experimental EMS frame uses `9000:0000`. That frame is writable and backed, but it is not carved out of the DOS MCB arena; reserving 64 KiB there drops Wolfenstein 3D below its conventional-memory threshold, while leaving it unreserved can corrupt programs that also allocate that range. Default builds therefore hide EMS.

The kernel image and stack live in the High Memory Area (FFFF:0010), so low memory holds only the disk buffers and the DOS arena starts at 0B00:0000 (~595 KiB free conventional memory; the base matches the lowest program placement real DOS produced, since era software breaks below it). The kernel enables the A20 line at boot and its XMS shim reports A20 as permanently enabled. See `src/memory.inc` and the compile-time assertions near the end of `src/kernel.asm` before moving buffers or adding large kernel features.

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

## Project Tracking

- Open work lives in `meta/issues.md` and detailed files under `meta/issues/`.
- Completed phases and compatibility fixes are archived in `meta/issues_archive.md`.
- Non-trivial investigations are recorded in `docs/debug_log.md`.
- `docs/gpt_handoff.md` is the original planning handoff. Treat it as historical background, not current status.
