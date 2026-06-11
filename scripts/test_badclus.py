#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "badclus.img")
KERNEL = os.path.join(BUILDDIR, "badclus_kernel.bin")
TIMEOUT = 10
SECTOR = 512
FAT_START = 1 * SECTOR
ROOT_START = 19 * SECTOR
ROOT_ENTRIES = 224


def fat12_set(fat, cluster, value):
    off = cluster + cluster // 2
    if cluster & 1:
        fat[off] = (fat[off] & 0x0F) | ((value << 4) & 0xF0)
        fat[off + 1] = (value >> 4) & 0xFF
    else:
        fat[off] = value & 0xFF
        fat[off + 1] = (fat[off + 1] & 0xF0) | ((value >> 8) & 0x0F)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    program = os.path.join(BUILDDIR, "badclus.com")
    baddat = os.path.join(BUILDDIR, "badclus.dat")
    with open(baddat, "wb") as f:
        f.write(b"B" * 1024)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="BADCLUS COM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/badclus.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, program, baddat])

    with open(IMG, "r+b") as f:
        img = bytearray(f.read())
        start = None
        for i in range(ROOT_ENTRIES):
            entry = img[ROOT_START + i * 32:ROOT_START + i * 32 + 32]
            if entry[:11] == b"BADCLUS DAT":
                start = entry[26] | (entry[27] << 8)
                break
        if start is None:
            raise SystemExit("BADCLUS.DAT not found in root directory")
        fat = img[FAT_START:FAT_START + 9 * SECTOR]
        fat12_set(fat, start, 0xFF7)
        img[FAT_START:FAT_START + 9 * SECTOR] = fat
        f.seek(0)
        f.write(img)


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    passed = check_markers(
        output,
        required=("PASS: BADCLUS DEL", "PASS: BADCLUS CREATE",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="badclus QEMU serial output")
    if not passed:
        sys.exit(1)
    print("\nBad-cluster chain free test passed.")


if __name__ == "__main__":
    main()
