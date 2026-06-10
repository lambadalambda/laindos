#!/usr/bin/env python3
import os
import struct

from fatlib import FatImage, entry_cluster, find_entry
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "dirextfail.img")
KERNEL = os.path.join(BUILDDIR, "dirextfail_kernel.bin")
TIMEOUT = 8


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", "-DTEST_DIR_EXT_ZERO_FAIL", '-DBOOT_FILE="DIREXTFACOM"',
        "-f", "bin", "src/kernel.asm", "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "tests/programs/dirextfail.asm", "-o", os.path.join(BUILDDIR, "dirextfa.com")])
    fillers = []
    for i in range(14):
        fillers.append(write_fixture(f"dfill{i:02d}.dat", f"filler {i:02d}\n".encode("ascii")))
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "dirextfa.com"),
        *[f"FULLDIR:{path}" for path in fillers],
    ])


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


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
