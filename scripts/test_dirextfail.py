#!/usr/bin/env python3
import os
import struct

from fatlib import FatImage, entry_cluster, find_entry
import subprocess
import sys
from testlib import run_serial_image, run_cmd, build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "dirextfail.img")
KERNEL = os.path.join(BUILDDIR, "dirextfail_kernel.bin")
TIMEOUT = 8


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", "-DTEST_DIR_EXT_ZERO_FAIL", '-DBOOT_FILE="DIREXTFACOM"',
        "-f", "bin", "src/kernel.asm", "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/dirextfail.asm", "-o", os.path.join(BUILDDIR, "dirextfa.com")])
    fillers = []
    for i in range(14):
        fillers.append(write_fixture(f"dfill{i:02d}.dat", f"filler {i:02d}\n".encode("ascii")))
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "dirextfa.com"),
        *[f"FULLDIR:{path}" for path in fillers],
    ])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def verify_disk():
    img = FatImage.from_file(IMG)
    root = img.root_dir()
    full = find_entry(root, "FULLDIR")
    if full is None or full[11] & 0x10 == 0:
        print("  FAIL: FULLDIR missing")
        return False
    cluster = entry_cluster(full)
    chain = img.cluster_chain(cluster)
    if len(chain) != 1:
        print(f"  FAIL: FULLDIR chain was extended after failed write: {chain}")
        return False
    print("  PASS: failed extension did not persist FAT link")
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: DIREXTFAIL", "Program exited, code=00"]:
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
    print("\nDirectory extension rollback test passed.")


if __name__ == "__main__":
    main()
