#!/usr/bin/env python3
import os
import shutil
import struct
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
RAW_IMG = os.path.join(BUILDDIR, "fat16part_volume.img")
IMG = os.path.join(BUILDDIR, "fat16part.img")
KERNEL = os.path.join(BUILDDIR, "fat16part_kernel.bin")
PART_START = 63
SECTOR_SIZE = 512
HEADS = 16
SPT = 63
TIMEOUT = 10


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


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


def build_partitioned_image(mbr_path):
    with open(RAW_IMG, "rb") as f:
        volume = bytearray(f.read())
    if len(volume) % SECTOR_SIZE != 0:
        raise RuntimeError("raw volume size is not sector-aligned")
    total = len(volume) // SECTOR_SIZE
    struct.pack_into("<I", volume, 0x1C, PART_START)

    with open(mbr_path, "rb") as f:
        mbr = bytearray(f.read())
    if len(mbr) != SECTOR_SIZE:
        raise RuntimeError("MBR is not one sector")

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
    with open(IMG, "wb") as f:
        f.write(image)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    mbr = os.path.join(BUILDDIR, "mbr.bin")
    boot = os.path.join(BUILDDIR, "fat16part_boot.bin")
    memtest = os.path.join(BUILDDIR, "memtest.exe")
    run(["nasm", "-f", "bin", "tests/programs/mbr.asm", "-o", mbr])
    run(["nasm", "-f", "bin", "src/boot16.asm", "-o", boot])
    run(["nasm", "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run(["nasm", "-f", "bin", "tests/programs/memtest.asm", "-o", memtest])
    run(["python3", "scripts/mkimage.py", "--format=hd32m", boot, KERNEL, RAW_IMG, memtest])
    build_partitioned_image(mbr)


def inspect_image():
    with open(IMG, "rb") as f:
        image = f.read((PART_START + 1) * SECTOR_SIZE)
    if image[510:512] != b"\x55\xAA":
        raise RuntimeError("missing MBR signature")
    entry = image[446:462]
    if entry[0] != 0x80 or entry[4] != 0x06:
        raise RuntimeError("missing active FAT16 partition entry")
    start = struct.unpack_from("<I", entry, 8)[0]
    if start != PART_START:
        raise RuntimeError("partition start mismatch")
    vbr = image[PART_START * SECTOR_SIZE:(PART_START + 1) * SECTOR_SIZE]
    if vbr[510:512] != b"\x55\xAA":
        raise RuntimeError("missing partition boot signature")
    if vbr[0x36:0x3E] != b"FAT16   ":
        raise RuntimeError("partition is not marked FAT16")
    hidden = struct.unpack_from("<I", vbr, 0x1C)[0]
    if hidden != PART_START:
        raise RuntimeError("BPB hidden-sector field mismatch")
    if vbr[3:11] != b"MSDOS5.0":
        raise RuntimeError("unexpected FAT OEM string")
    if vbr[0x2B:0x36] != b"NO NAME    ":
        raise RuntimeError("unexpected FAT volume label")


def run_host_fat_check():
    if shutil.which("fsck_msdos") is None:
        print("  SKIP: fsck_msdos unavailable for host FAT check")
        return
    with open(IMG, "rb") as f:
        f.seek(PART_START * SECTOR_SIZE)
        part = f.read(os.path.getsize(RAW_IMG))
    part_img = os.path.join(BUILDDIR, "fat16part_slice.img")
    with open(part_img, "wb") as f:
        f.write(part)
    result = subprocess.run(["fsck_msdos", "-n", part_img], capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        raise RuntimeError("fsck_msdos rejected partition FAT16 filesystem")


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def main():
    build_image()
    inspect_image()
    run_host_fat_check()
    output = run_qemu()
    failed = False
    for marker in [
        "MiniDOS booted",
        "PASS: MEM",
        "Program exited, code=00",
        "HALT",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH=", "No active partition", "Partition boot read failed"]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nPartitioned FAT16 boot test passed.")


if __name__ == "__main__":
    main()
