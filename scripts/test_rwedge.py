#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "rwedge.img")
KERNEL = os.path.join(BUILDDIR, "rwedge_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "rwedge_boot.bin")
    prog = os.path.join(BUILDDIR, "rwedge.com")
    data = os.path.join(BUILDDIR, "rwedge.dat")
    with open(data, "wb") as handle:
        handle.write(b"ABCDE")
    run_cmd(["nasm", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="RWEDGE  COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/rwedge.asm", "-o", prog])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, prog, data])


def main():
    build_image()
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    if not check_markers(output, required=("PASS: RWEDGE", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nRead/write edge test passed.")


if __name__ == "__main__":
    main()
