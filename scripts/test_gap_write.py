#!/usr/bin/env python3
"""Write-past-EOF extends by allocating clusters, not zero-filling sectors.

A DOS extender reserves its swap by seeking far past EOF and writing one
byte; faithful DOS allocates the gap's clusters and leaves their contents
undefined. LainDOS used to read-modify-write every gap sector with zeros
and, on FAT16, commit both FAT copies per entry -- tens of thousands of
sector writes that stalled Red Alert on the DOS/4GW screen at real IDE
speed. This pins the corrected behavior: a 4 MiB gap extend produces the
right size, the marker past it is intact, and the gap still reads back as
zero on a freshly formatted volume (where the new clusters were never
written).
"""
import os
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "gapwrite.img")
KERNEL = os.path.join(BUILDDIR, "gapwrite_kernel.bin")
BOOT = os.path.join(BUILDDIR, "gapwrite_boot.bin")
PROGRAM = os.path.join(BUILDDIR, "gapwrite.com")
TIMEOUT = 20


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="GAPWRITECOM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/gapwrite.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")
    ok = check_markers(
        output,
        required=("LainDOS booted", "PASS: GAPWRITE", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="gap-write QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nGap-write (write-past-EOF) test passed.")


if __name__ == "__main__":
    main()
