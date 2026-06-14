#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "shelltab.img")
KERNEL = os.path.join(BUILDDIR, "shelltab_kernel.bin")
TIMEOUT = 15


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_shelltab.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/build_shell_com.py", shell])
    with open(autoexec, "wb") as f:
        f.write(b"echo off\r\n"
                b"\techo TABLINE\r\n"
                b"echo\tTABARG\r\n"
                b"\t\techo  \t DEEPTAB\r\n"
                b"echo FILED\t>TB.TXT\r\n"
                b"type\tTB.TXT\r\n"
                b"echo TABDONE\r\n"
                b"exit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, autoexec])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    required = ("TABLINE", "TABARG", "DEEPTAB", "FILED", "TABDONE", "HALT")
    forbidden = ("Bad command", "File not found")
    if not check_markers(output, required=required, forbidden=forbidden):
        sys.exit(1)
    print("\nShell tab-whitespace test passed.")


if __name__ == "__main__":
    main()
