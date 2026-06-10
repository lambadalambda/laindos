#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "loopchn.img")
KERNEL = os.path.join(BUILDDIR, "loopchn_kernel.bin")
TIMEOUT = 10
SECTOR = 512
FAT_START = 1 * SECTOR
ROOT_START = 19 * SECTOR
ROOT_ENTRIES = 224


def fat12_get(fat, cluster):
    off = cluster + cluster // 2
    val = fat[off] | (fat[off + 1] << 8)
    if cluster & 1:
        return val >> 4
    return val & 0xFFF


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
    program = os.path.join(BUILDDIR, "loopchn.com")
    fillers = []
    for i in range(14):
        path = os.path.join(BUILDDIR, f"ld{i:02d}.dat")
        with open(path, "wb") as f:
            f.write(b"L")
        fillers.append(f"LOOPDIR:{path}")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="LOOPCHN COM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/loopchn.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, program,
             *fillers])

    with open(IMG, "r+b") as f:
        img = bytearray(f.read())
        start = None
        for i in range(ROOT_ENTRIES):
            entry = img[ROOT_START + i * 32:ROOT_START + i * 32 + 32]
            if entry[:11] == b"LOOPDIR    " and entry[11] & 0x10:
                start = entry[26] | (entry[27] << 8)
                break
        if start is None:
            raise SystemExit("LOOPDIR not found in root directory")
        fat = img[FAT_START:FAT_START + 9 * SECTOR]
        assert fat12_get(fat, start) not in (0, 0xFF7)
        fat12_set(fat, start, start)
        img[FAT_START:FAT_START + 9 * SECTOR] = fat
        f.seek(0)
        f.write(img)


def main():
    build_image()
    output, timed_out = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    passed = check_markers(
        output,
        required=("PASS: LOOPCHN", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="loopchn QEMU serial output")
    if not passed or timed_out:
        if timed_out:
            print("  FAIL: QEMU run timed out (kernel hung on looped chain)")
        sys.exit(1)
    print("\nFAT chain cycle guard test passed.")


if __name__ == "__main__":
    main()
