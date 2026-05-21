# LainDOS

A tiny single-tasking DOS implementation whose first serious target is booting and running **The Secret of Monkey Island** (VGA, 1990).

This is not a general-purpose FreeDOS replacement. It implements only the subset of DOS needed to boot, load `MONKEY.EXE`, serve its file/memory/version/vector calls, and otherwise stay out of the way of BIOS/VGA/timer/keyboard hardware.

## Goals

- Boot from a FAT disk image in QEMU
- Load a kernel (`KERNEL.SYS`) from the FAT filesystem
- Implement enough `INT 21h` to run Monkey Island
- MZ `.EXE` loader with PSP, relocation, and MCB memory allocator
- Serial debug logging from day one
- No shell required — the kernel directly EXECs the target program

## Non-goals (initially)

- DPMI, VCPI, EMS, XMS
- Hard disk partitioning beyond one simple FAT volume
- DOS device drivers or `CONFIG.SYS`
- Full `COMMAND.COM`
- Sound Blaster, AdLib, MT-32
- Printing, networking, SHARE, redirectors

## Architecture

Single real-mode, non-reentrant, single-tasking kernel.

```
0000:0000  Interrupt Vector Table
0040:0000  BIOS Data Area
0050:0000  scratch / low DOS data
0070:0000  bootloader transient area
0800:0000  tiny DOS kernel, disk buffers, handle tables
1000:0000  start of allocatable DOS memory
A000:0000  VGA graphics memory
```

Disk I/O delegates to BIOS `INT 13h`. The filesystem layer implements FAT12 initially, with FAT16 to follow.

## Toolchain

- **Assembly:** NASM (boot sector, interrupt trampolines, real-mode glue)
- **C compiler:** Open Watcom (16-bit DOS targets)
- **Emulation:** QEMU (primary), Bochs (debugging)
- **References:** Ralf Brown's Interrupt List, MS-DOS 4.00 source (MIT), FreeDOS kernel (GPL — conceptual reference only, do not copy code)

## Implementation Phases

| Phase | Deliverable |
|-------|-------------|
| 1 | Bootable kernel — boots, loads `KERNEL.SYS`, prints memory size, reads FAT files |
| 2 | `.COM` loader — runs `HELLO.COM`, termination works |
| 3 | MZ `.EXE` loader — runs `HELLO.EXE`, relocation, PSP, CS:IP/SS:SP |
| 4 | Filesystem handles — open/read/seek/close, FindFirst/FindNext |
| 5 | DOS memory allocator — alloc/resize/free, MCB chain |
| 6 | Direct boot into Monkey Island — kernel EXECs `MONKEY.EXE`, logs missing calls |
| 7 | Implement missing calls until visible start, keyboard works |
| 8 | Mouse shim — `INT 33h`, pointer/buttons |
| 9 | Save-game writes — create/write/close/rename/date |

## Test Strategy

1. **Tiny programs** — compile small 16-bit DOS test programs (open/read/seek/close, malloc/free, findfirst, get/set vector, get version)
2. **Simple utilities** — `HELLO.COM`, `HELLO.EXE`, `READFILE.EXE`, `DIRLIKE.EXE`, `MEMTEST.EXE`, `EXECCHILD.EXE`
3. **Monkey Island** — skip installer, copy installed game files onto disk image, run `MONKEY.EXE`, inspect unhandled interrupts

## Version Lie

`INT 21h AH=30h` returns DOS 3.30 by default. Many era games prefer 3.x semantics. Switch to 4.00 only if required.

## Debugging

Serial log to COM1 from day one. Log boot progress, FAT opens, file reads/seeks, EXEC loads, MZ relocations, `INT 21h` calls, allocations, and unhandled interrupts.
