#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
from testlib import build_dir, run_cmd, run_serial_image
from fatlib import FatImage, entry_cluster, entry_size, find_entry

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "highdir.img")
KERNEL = os.path.join(BUILDDIR, "highdir_kernel.bin")
TIMEOUT = 20
SEED = b"seed-high-dir"
OUT = b"high-lba-dir-write"
HIGH_LBA_MIN = 0x10000


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "highdir_boot.bin")
    highdir = os.path.join(BUILDDIR, "highdir.com")
    filler = os.path.join(BUILDDIR, "highdir_fill.dat")
    seed = os.path.join(BUILDDIR, "seed.dat")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="HIGHDIR COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/highdir.asm", "-o", highdir])
    with open(filler, "wb") as f:
        f.truncate(34 * 1024 * 1024)
    with open(seed, "wb") as f:
        f.write(SEED)
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", boot, KERNEL, IMG, highdir, filler, f"HIDIR:{seed}"])


def run_qemu():
    output = run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")
    return output


def verify_disk():
    img = FatImage.from_file(IMG)
    root = img.root_dir()

    hidir = find_entry(root, "HIDIR")
    if hidir is None or hidir[11] & 0x10 == 0:
        print("  FAIL: HIDIR missing from root")
        return False
    hidir_cluster = entry_cluster(hidir)
    hidir_lba = (img.cluster_off(hidir_cluster) - img.offset) // img.bps
    if hidir_lba < HIGH_LBA_MIN:
        print(f"  FAIL: HIDIR LBA is not high: {hidir_lba}")
        return False
    directory = img.read_chain(hidir_cluster)
    renamed = find_entry(directory, "RENAMED.DAT")
    if renamed is None:
        print("  FAIL: RENAMED.DAT missing from high directory")
        return False
    if renamed[11] != 0x02:
        print("  FAIL: RENAMED.DAT attribute change was not flushed")
        return False
    if entry_size(renamed) != len(OUT):
        print("  FAIL: RENAMED.DAT size was not flushed")
        return False
    if find_entry(directory, "SUBTEMP") is not None:
        print("  FAIL: SUBTEMP directory still active after rmdir")
        return False
    if find_entry(directory, "DELME.DAT") is not None:
        print("  FAIL: DELME.DAT still active after delete")
        return False
    out_cluster = entry_cluster(renamed)
    if out_cluster < 2:
        print("  FAIL: RENAMED.DAT cluster was not flushed")
        return False
    data = img.read_chain(out_cluster, len(OUT))
    if data != OUT:
        print("  FAIL: RENAMED.DAT contents mismatch")
        return False
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in [
        "LainDOS booted",
        "PASS: HIGHDIR",
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
    if not verify_disk():
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nHigh-LBA FAT16 directory test passed.")


if __name__ == "__main__":
    main()
