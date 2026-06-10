#!/usr/bin/env python3
import os
import struct

from fatlib import FatImage, entry_cluster, entry_size, find_entry
import subprocess
import sys
from testlib import run_serial_image, run_cmd, build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "termflush.img")
KERNEL = os.path.join(BUILDDIR, "termflush_kernel.bin")
TIMEOUT = 8
PAYLOAD = b"termination flush payload\r\n"


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="TERMFLUSCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/termflush.asm", "-o", os.path.join(BUILDDIR, "termflus.com")])
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "termflus.com"),
    ])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def verify_disk():
    img = FatImage.from_file(IMG)
    entry = find_entry(img.root_dir(), "TERMOUT.DAT")
    if entry is None:
        print("  FAIL: TERMOUT.DAT missing")
        return False
    cluster = entry_cluster(entry)
    size = entry_size(entry)
    if size != len(PAYLOAD):
        print(f"  FAIL: TERMOUT.DAT size {size}, expected {len(PAYLOAD)}")
        return False
    if cluster < 2:
        print(f"  FAIL: TERMOUT.DAT invalid start cluster {cluster}")
        return False
    if img.read_chain(cluster, len(PAYLOAD)) != PAYLOAD:
        print("  FAIL: TERMOUT.DAT payload mismatch")
        return False
    print("  PASS: termination flushed written handle")
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: TERMFLUSH", "Program exited, code=00"]:
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
    print("\nTermination flush test passed.")


if __name__ == "__main__":
    main()
