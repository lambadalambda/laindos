#!/usr/bin/env python3
import os
import struct

from fatlib import FatImage, entry_cluster, find_entry
import sys
from testlib import build_dir, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "dirextrollback.img")
KERNEL = os.path.join(BUILDDIR, "dirextrollback_kernel.bin")
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
        "nasm", "-DTEST_DIR_EXT_ZERO_FAIL", "-DTEST_DIR_EXT_FLUSH_BEFORE_ZERO_FAIL",
        '-DBOOT_FILE="DIREXTRBCOM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/dirextrb.asm", "-o", os.path.join(BUILDDIR, "dirextrb.com")])
    fillers = []
    for i in range(14):
        fillers.append(write_fixture(f"rfill{i:02d}.dat", f"rollback filler {i:02d}\n".encode("ascii")))
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "dirextrb.com"),
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
    full = find_entry(img.root_dir(), "FULLDIR")
    if full is None or full[11] & 0x10 == 0:
        print("  FAIL: FULLDIR missing")
        return False
    cluster = entry_cluster(full)
    for copy in range(img.fat_count):
        chain = FatImage.from_file(IMG, fat_index=copy).cluster_chain(cluster)
        if len(chain) != 1:
            print(f"  FAIL: FAT copy {copy + 1} kept failed directory extension: {chain}")
            return False
    print("  PASS: rollback persisted to all FAT copies")
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: DIREXTROLL", "Program exited, code=00"]:
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
    print("\nDirectory extension rollback persistence test passed.")


if __name__ == "__main__":
    main()
