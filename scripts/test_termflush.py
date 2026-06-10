#!/usr/bin/env python3
import os
import struct

from fatlib import FatImage, entry_cluster, entry_size, find_entry
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "termflush.img")
KERNEL = os.path.join(BUILDDIR, "termflush_kernel.bin")
TIMEOUT = 8
PAYLOAD = b"termination flush payload\r\n"


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
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="TERMFLUSCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "tests/programs/termflush.asm", "-o", os.path.join(BUILDDIR, "termflus.com")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "termflus.com"),
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
