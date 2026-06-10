#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "batchif.img")
KERNEL = os.path.join(BUILDDIR, "batchif_kernel.bin")
TIMEOUT = 15


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    ret7 = os.path.join(BUILDDIR, "ret7.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_batchif.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", shell])
    run_cmd(["nasm", "-DRET_CODE=7", "-f", "bin", "tests/programs/retchild.asm", "-o", ret7])
    with open(autoexec, "wb") as f:
        f.write(b"echo off\r\n"
                b"echo START\r\n"
                b"if exist AUTOEXEC.BAT echo E1OK\r\n"
                b"if exist NOPE.ZZZ echo E2BAD\r\n"
                b"if not exist NOPE.ZZZ echo E3OK\r\n"
                b"if not exist AUTOEXEC.BAT echo E4BAD\r\n"
                b"ret7\r\n"
                b"if errorlevel 5 echo L1OK\r\n"
                b"if errorlevel 7 echo L2OK\r\n"
                b"if errorlevel 8 echo L3BAD\r\n"
                b"if not errorlevel 8 echo L4OK\r\n"
                b"if abc==abc echo S1OK\r\n"
                b"if abc==abd echo S2BAD\r\n"
                b"if not abc==abd echo S3OK\r\n"
                b"if bogus echo SYNBAD\r\n"
                b"echo IFDONE\r\n"
                b"exit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, ret7, autoexec])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    required = ("START", "E1OK", "E3OK", "L1OK", "L2OK", "L4OK",
                "S1OK", "S3OK", "Syntax error", "IFDONE", "HALT")
    forbidden = ("E2BAD", "E4BAD", "L3BAD", "S2BAD", "SYNBAD")
    if not check_markers(output, required=required, forbidden=forbidden):
        sys.exit(1)
    print("\nBatch IF test passed.")


if __name__ == "__main__":
    main()
