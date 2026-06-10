#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "shellcopy.img")
KERNEL = os.path.join(BUILDDIR, "shellcopy_kernel.bin")
TIMEOUT = 15


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_shellcopy.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", shell])
    with open(autoexec, "wb") as f:
        f.write(b"echo off\r\n"
                b"echo AAA >A1.TXT\r\n"
                b"echo BBB >A2.TXT\r\n"
                b"md SUB\r\n"
                b"copy A*.TXT SUB >NUL\r\n"
                b"type SUB\\A1.TXT\r\n"
                b"type SUB\\A2.TXT\r\n"
                b"md SUB2\r\n"
                b"cd SUB2\r\n"
                b"copy \\A2.TXT >NUL\r\n"
                b"type A2.TXT\r\n"
                b"cd \\\r\n"
                b"echo COPYDONE\r\n"
                b"exit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, autoexec])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    required = ("AAA", "BBB", "COPYDONE", "HALT")
    forbidden = ("File not found", "Missing argument", "FAIL")
    if not check_markers(output, required=required, forbidden=forbidden):
        sys.exit(1)
    print("\nShell copy test passed.")


if __name__ == "__main__":
    main()
