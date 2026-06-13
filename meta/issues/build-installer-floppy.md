# Build a self-booting LainDOS installer floppy

## Summary

A self-booting floppy that installs LainDOS onto a hard disk (and later a
second floppy). Boots to a shell; running `INSTALL` formats the target to
FAT16, sized to the detected disk, and copies the system files onto it,
making it bootable.

## Design

The installer is a guest `.COM` (`programs/install.asm`). The kernel
exposes no absolute-disk API (no INT 25h/26h, `write_sector` is private)
and will not auto-mount a freshly formatted disk until the next boot, so
the installer does everything at the sector level via **INT 13h**
directly, reading the system files and a FAT16 boot template off drive A:
with normal DOS calls.

Steps: detect target geometry (INT 13h AH=08h) -> compute a FAT16 BPB
(smallest cluster size that keeps the cluster count in FAT16 range, via
the FAT-spec fat-size formula) -> write the boot sector (BOOT16.BIN with a
patched BPB) -> copy each system file (contiguous clusters, stream the
data to the data area) -> write both FATs (streamed per sector, contiguous
chains) -> write the root directory. Then "remove the floppy and reboot."

`scripts/build_installer.py` builds the floppy; `scripts/test_installer.py`
installs to a blank QEMU hard disk and verifies the result host-side
(independent `fatlib`: valid FAT16, system files byte-exact). A manual
`--boot-check` boots from the installed hard disk to confirm it reaches a
C: shell.

## Status

- **Done (phase 1):** hard-disk target, full-disk FAT16 sizing, format +
  byte-exact file copy, bootable result. `INSTALL /Y` for scripted runs.
  `test_installer.py` is in the regression ladder; it gates on a
  deterministic host-side structural check (boot code byte-identical to
  the template + 0xAA55 + "FAT16" + byte-exact files). The live
  boot-to-C: shell is a manual `--boot-check`: launching a second QEMU
  from inside the test's process is environmentally flaky even though the
  image boots reliably from a separate process.
- Output is screen-only: a guest program's writes to COM1 (0x3F8) do not
  reach the captured serial under our harness, though the kernel's boot
  serial does -- not chased, since an installer's UI is the screen.

## Completion

- 2026-06-13: The hard-disk installer floppy is complete. `make installer`
  builds a self-booting floppy and `make test-installer` verifies installing
  to a blank FAT16 hard disk with byte-exact system files. Later UI/media
  enhancements are useful, but they are not blockers for this issue.

## Future Enhancements

- Second-floppy (B:) target (FAT12 path); needs a two-floppy config and
  the kernel does not currently expose B:.
- Interactive drive selection / target confirmation UI (enumerate INT 13h
  drives, show sizes, pick one) instead of a fixed 0x80.
- Disks larger than the INT 13h CHS limit (~504 MB): use EDD (AH=48h /
  AH=43h LBA) for geometry and writes.
- Volume label; optional MBR + partition table instead of a
  whole-disk (superfloppy) layout.
- Empty-file edge case: a zero-length source would get a dangling first
  cluster (all current system files are non-empty).
