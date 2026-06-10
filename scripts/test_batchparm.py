#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "batchparm.img")
KERNEL = os.path.join(BUILDDIR, "batchparm_kernel.bin")
TIMEOUT = 15


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_batchparm.bat")
    parmtest = os.path.join(BUILDDIR, "parmtest.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", shell])
    with open(parmtest, "wb") as f:
        f.write(b"echo off\r\n"
                b"echo P1=%1 P2=%2 M=%3 PP=%% P0=%0.\r\n")
    with open(autoexec, "wb") as f:
        f.write(b"echo off\r\n"
                b"parmtest HELLO WORLD\r\n"
                b"echo PARMDONE\r\n"
                b"exit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, autoexec, parmtest])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    required = ("P1=HELLO P2=WORLD M= PP=% P0=.", "PARMDONE", "HALT")
    if not check_markers(output, required=required):
        sys.exit(1)
    print("\nBatch parameter test passed.")


if __name__ == "__main__":
    main()
