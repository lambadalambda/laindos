#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "badfat.img")
KERNEL = os.path.join(BUILDDIR, "badfat_kernel.bin")
TIMEOUT = 15
BAD_FAT_FLOOR = 0x6000
FAT16_RESERVED = 0xFFF0
GOOD = b"root-ok-after-bad-fat"


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "badfat_boot.bin")
    badfat = os.path.join(BUILDDIR, "badfat.com")
    badchain = os.path.join(BUILDDIR, "badchain.dat")
    firstbad = os.path.join(BUILDDIR, "firstbad.dat")
    good = os.path.join(BUILDDIR, "good.dat")
    run(["nasm", "-f", "bin", "src/boot16.asm", "-o", boot])
    run(["nasm", '-DBOOT_FILE="BADFAT  COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run(["nasm", "-f", "bin", "tests/programs/badfat.asm", "-o", badfat])
    with open(badchain, "wb") as f:
        f.write(b"B" * 4608)
    with open(firstbad, "wb") as f:
        f.write(b"first-cluster-is-bad")
    with open(good, "wb") as f:
        f.write(GOOD)
    run(["python3", "scripts/mkimage.py", "--format=hd96m", boot, KERNEL, IMG, badfat, badchain, firstbad, good])
    corrupt_badchain()


def find_root_entry(image, name):
    bps = struct.unpack_from("<H", image, 0x0B)[0]
    reserved = struct.unpack_from("<H", image, 0x0E)[0]
    fats = image[0x10]
    root_entries = struct.unpack_from("<H", image, 0x11)[0]
    fat_secs = struct.unpack_from("<H", image, 0x16)[0]
    root_start = reserved + fats * fat_secs
    root_secs = (root_entries * 32 + bps - 1) // bps
    root_off = root_start * bps
    for off in range(root_off, root_off + root_secs * bps, 32):
        entry = image[off:off + 32]
        if entry[0] == 0:
            break
        if entry[0] != 0xE5 and entry[0:11] == name:
            return off, entry
    raise RuntimeError(f"missing root entry {name!r}")


def corrupt_badchain():
    with open(IMG, "r+b") as f:
        image = bytearray(f.read())
        bps = struct.unpack_from("<H", image, 0x0B)[0]
        reserved = struct.unpack_from("<H", image, 0x0E)[0]
        fats = image[0x10]
        spc = image[0x0D]
        root_entries = struct.unpack_from("<H", image, 0x11)[0]
        total = struct.unpack_from("<H", image, 0x13)[0]
        if total == 0:
            total = struct.unpack_from("<I", image, 0x20)[0]
        fat_secs = struct.unpack_from("<H", image, 0x16)[0]
        root_secs = (root_entries * 32 + bps - 1) // bps
        data_start = reserved + fats * fat_secs + root_secs
        kmax_cluster = (total - data_start) // spc + 2
        bad_fat_value = max(BAD_FAT_FLOOR, kmax_cluster + 33, (fat_secs + 16) << 8)
        if bad_fat_value >= FAT16_RESERVED:
            bad_fat_value = FAT16_RESERVED - 1
        if bad_fat_value < kmax_cluster:
            raise RuntimeError("could not choose an invalid FAT16 cluster value")
        _, entry = find_root_entry(image, b"BADCHAINDAT")
        first_cluster = struct.unpack_from("<H", entry, 26)[0]
        for copy in range(fats):
            off = (reserved + copy * fat_secs) * bps + first_cluster * 2
            struct.pack_into("<H", image, off, bad_fat_value)
        firstbad_off, _ = find_root_entry(image, b"FIRSTBADDAT")
        struct.pack_into("<H", image, firstbad_off + 26, bad_fat_value)
        f.seek(0)
        f.write(image)


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
    output = run_qemu()
    failed = False
    for marker in [
        "LainDOS booted",
        "PASS: BADFAT",
        "Program exited, code=00",
        "HALT",
    ]:
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
    print("\nBad FAT cluster bounds test passed.")


if __name__ == "__main__":
    main()
