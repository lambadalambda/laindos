# Phase 1: Bootable Kernel

## Summary

Write a 512-byte boot sector that loads KERNEL.SYS from the FAT12 root directory, and a minimal kernel that prints a boot message and memory size.

## Requirements

- Boot sector: 512 bytes, loads KERNEL.SYS by name from FAT12 root directory, follows cluster chain
- Kernel: prints "MiniDOS booted" and conventional memory size (via INT 12h)
- Kernel can read sectors using BIOS INT 13h
- Install interrupt handlers: INT 20h (terminate), INT 21h (DOS API dispatcher, mostly stubs initially), INT 22h/23h/24h (stub vectors)
- Boot sector and kernel boot successfully in QEMU

## Acceptance Criteria

- QEMU boots the disk image and serial output shows "MiniDOS booted"
- Serial output shows reported conventional memory size
- Boot sector correctly locates and loads KERNEL.SYS from FAT12 filesystem
- Boot sector handles KERNEL.SYS sizes of at least 20-60 KiB
- INT 20h and INT 21h are installed and reachable
