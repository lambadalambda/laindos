#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "shellredir.img")
KERNEL = os.path.join(BUILDDIR, "shellredir_kernel.bin")
TIMEOUT = 15


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_shellredir.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/build_shell_com.py", shell])
    with open(autoexec, "wb") as f:
        f.write(b"echo off\r\n"
                b"echo REDIRSTART\r\n"
                b"echo HIDDENWORD >NUL\r\n"
                b"echo FILED >RD.TXT\r\n"
                b"type RD.TXT\r\n"
                b"echo APPENDED >>RD.TXT\r\n"
                b"copy RD.TXT RD2.TXT >NUL\r\n"
                b"type RD2.TXT\r\n"
                b"shell /C echo NESTED\r\n"
                b"shell /C copy RD.TXT RD3.TXT >NUL\r\n"
                b"echo NESTDONE\r\n"
                b"echo REDIRDONE\r\n"
                b"exit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, autoexec])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    required = ("REDIRSTART", "FILED", "APPENDED", "NESTED", "NESTDONE", "REDIRDONE", "HALT")
    forbidden = ("HIDDENWORD", "File(s) copied", "Overwrite")
    if not check_markers(output, required=required, forbidden=forbidden):
        sys.exit(1)
    banners = output.count("LainDOS Shell")
    if banners != 1:
        print(f"FAIL: expected 1 shell banner, saw {banners}")
        sys.exit(1)
    print("\nShell redirection test passed.")


if __name__ == "__main__":
    main()
