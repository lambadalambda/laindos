#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
BOOT = os.path.join(BUILDDIR, "shellmem_boot.bin")
KERNEL = os.path.join(BUILDDIR, "shellmem_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
PROGRAM = os.path.join(BUILDDIR, "shellmem.com")
AUTOEXEC = os.path.join(BUILDDIR, "autoexec_shellmem.bat")
IMG = os.path.join(BUILDDIR, "shellmem.img")


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/build_shell_com.py", SHELL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/shellmem.asm", "-o", PROGRAM])
    with open(AUTOEXEC, "wb") as f:
        f.write(b"shellmem\r\nexit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, SHELL, PROGRAM, AUTOEXEC])
    output = run_serial_image(IMG, timeout=12)
    if not check_markers(output, required=("PASS: SHELLMEM", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nShell conventional-memory floor test passed.")


if __name__ == "__main__":
    main()
