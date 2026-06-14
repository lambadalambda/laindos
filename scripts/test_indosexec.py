#!/usr/bin/env python3
"""A program EXEC'd by the shell must run with InDOS back at zero."""
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "indosexec.img")
KERNEL = os.path.join(BUILDDIR, "indosexec_kernel.bin")
TIMEOUT = 15


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    prog = os.path.join(BUILDDIR, "indosex.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_indosexec.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/build_shell_com.py", shell])
    run_cmd(["nasm", "-f", "bin", "tests/programs/indosexec.asm", "-o", prog])
    with open(autoexec, "wb") as f:
        f.write(b"indosex\r\nexit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, prog, autoexec])
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: INDOSEXEC", "HALT"),
                         forbidden=("FAIL:", "EXC ")):
        sys.exit(1)
    print("\nInDOS-during-EXEC test passed.")


if __name__ == "__main__":
    main()
