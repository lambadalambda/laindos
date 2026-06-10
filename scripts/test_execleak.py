#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "execleak.img")
KERNEL = os.path.join(BUILDDIR, "execleak_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    program = os.path.join(BUILDDIR, "execleak.com")
    badrel = os.path.join(BUILDDIR, "badrel.exe")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="EXECLEAKCOM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/execleak.asm", "-o", program])
    run_cmd(["python3", "scripts/mkbadreloc.py", badrel])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, program, badrel])


def main():
    build_image()
    output, timed_out = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    passed = check_markers(
        output,
        required=("PASS: EXECLEAK EXEC", "PASS: EXECLEAK NOLEAK",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="execleak QEMU serial output")
    if not passed or timed_out:
        if timed_out:
            print("  FAIL: QEMU run timed out")
        sys.exit(1)
    print("\nEXEC failure handle refcount test passed.")


if __name__ == "__main__":
    main()
