#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
FLOPPY_IMG = os.path.join(BUILDDIR, "aliasdrv_floppy.img")
HD_IMG = os.path.join(BUILDDIR, "aliasdrv_hd.img")
KERNEL = os.path.join(BUILDDIR, "aliasdrv_kernel.bin")
TIMEOUT = 12


def build_images():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    boot16 = os.path.join(BUILDDIR, "boot16.bin")
    program = os.path.join(BUILDDIR, "aliasdrv.com")
    aonly = os.path.join(BUILDDIR, "aonly.txt")
    with open(aonly, "wb") as f:
        f.write(b"DRIVEOK")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot16])
    run_cmd(["nasm", '-DBOOT_FILE="ALIASDRVCOM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/aliasdrv.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, FLOPPY_IMG,
             program, aonly])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", boot16, KERNEL,
             HD_IMG])


def main():
    build_images()
    output, timed_out = run_qemu_capture([
        QEMU,
        "-drive", f"file={FLOPPY_IMG},format=raw,if=floppy",
        "-drive", f"file={HD_IMG},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    passed = check_markers(
        output,
        required=("PASS: ALIASDRV CFILE", "PASS: ALIASDRV AFILE",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="aliasdrv QEMU serial output")
    if not passed or timed_out:
        if timed_out:
            print("  FAIL: QEMU run timed out")
        sys.exit(1)
    print("\nAlias promotion drive test passed.")


if __name__ == "__main__":
    main()
