#!/usr/bin/env python3
import os
import struct
import sys

from testlib import build_dir, run_cmd, run_serial_image


QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
FLOPPY_IMG = os.path.join(BUILDDIR, "multidrive_floppy.img")
HD_IMG = os.path.join(BUILDDIR, "multidrive_hd.img")
HD_PART_VOL = os.path.join(BUILDDIR, "multidrive_hd_part_volume.img")
HD_PART_IMG = os.path.join(BUILDDIR, "multidrive_hd_part.img")
KERNEL = os.path.join(BUILDDIR, "multidrive_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
BOOT16 = os.path.join(BUILDDIR, "boot16.bin")
MBR = os.path.join(BUILDDIR, "mbr.bin")
PROGRAM = os.path.join(BUILDDIR, "multidrv.com")
ENVTEST = os.path.join(BUILDDIR, "envtest.com")
AONLY = os.path.join(BUILDDIR, "aonly.txt")
HDONLY = os.path.join(BUILDDIR, "hdonly.txt")
PART_START = 63
HEADS = 16
SPT = 63
SECTOR_SIZE = 512
TIMEOUT = 12


def chs(lba):
    cyl = lba // (HEADS * SPT)
    rem = lba % (HEADS * SPT)
    head = rem // SPT
    sector = (rem % SPT) + 1
    if cyl > 1023:
        cyl = 1023
        head = 254
        sector = 63
    return bytes([head, sector | ((cyl >> 2) & 0xC0), cyl & 0xFF])


def build_partitioned_hd():
    with open(HD_PART_VOL, "rb") as f:
        volume = bytearray(f.read())
    total = len(volume) // SECTOR_SIZE

    with open(MBR, "rb") as f:
        mbr = bytearray(f.read())
    entry = bytearray(16)
    entry[0] = 0x80
    entry[1:4] = chs(PART_START)
    entry[4] = 0x06
    entry[5:8] = chs(PART_START + total - 1)
    struct.pack_into("<I", entry, 8, PART_START)
    struct.pack_into("<I", entry, 12, total)
    mbr[446:462] = entry

    image = bytearray((PART_START + total) * SECTOR_SIZE)
    image[:SECTOR_SIZE] = mbr
    start = PART_START * SECTOR_SIZE
    image[start:start + len(volume)] = volume
    with open(HD_PART_IMG, "wb") as f:
        f.write(image)


def build_images():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(AONLY, "wb") as f:
        f.write(b"DRIVEOK")
    with open(HDONLY, "wb") as f:
        f.write(b"DRIVEOK")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT16])
    run_cmd(["nasm", "-f", "bin", "tests/programs/mbr.asm", "-o", MBR])
    run_cmd([
        "nasm", '-DBOOT_FILE="MULTIDRVCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/multidrive.asm", "-o", PROGRAM])
    run_cmd(["nasm", "-f", "bin", "tests/programs/envtest.asm", "-o", ENVTEST])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, FLOPPY_IMG, PROGRAM, ENVTEST, AONLY])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT16, KERNEL, HD_IMG, HDONLY])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd32m", BOOT16, KERNEL, HD_PART_VOL, HDONLY])
    build_partitioned_hd()


def run_qemu(hd_img):
    output = run_serial_image(FLOPPY_IMG, TIMEOUT, extra_args=("-drive", f"file={hd_img},format=raw,if=ide,index=0,media=disk"))
    return output


def check_output(label, output):
    failed = False
    print(f"\nChecking {label} multi-drive run.")
    for marker in ["PASS: MULTIDRIVE", "Program exited, code=00", "HALT"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)


def main():
    build_images()
    check_output("raw", run_qemu(HD_IMG))
    check_output("partitioned", run_qemu(HD_PART_IMG))
    print("\nMulti-drive test passed.")


if __name__ == "__main__":
    main()
