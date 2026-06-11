#!/usr/bin/env python3
"""An EXEC'd program must start with IF=1 and see the BIOS tick advance.

Mirrors the Stunt Island post-intro wait: the game spins on 40:6C without
executing STI itself, relying on DOS launching programs with interrupts
enabled and preserving caller IF across INT 21h.
"""
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "tickspin.img")
KERNEL = os.path.join(BUILDDIR, "tickspin_kernel.bin")
TIMEOUT = 20


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    prog = os.path.join(BUILDDIR, "tickspin.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_tickspin.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", shell])
    run_cmd(["nasm", "-f", "bin", "tests/programs/tickspin.asm", "-o", prog])
    with open(autoexec, "wb") as f:
        f.write(b"tickspin\r\nexit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, prog, autoexec])
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: TICKSPIN", "HALT"),
                         forbidden=("FAIL:", "EXC ")):
        sys.exit(1)
    print("\nTick-spin IF inheritance test passed.")


if __name__ == "__main__":
    main()
