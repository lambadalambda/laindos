#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
FLOPPY_IMG = os.path.join(BUILDDIR, "misc21_floppy.img")
HD_IMG = os.path.join(BUILDDIR, "misc21_hd.img")
KERNEL = os.path.join(BUILDDIR, "misc21_kernel.bin")
TIMEOUT = 12


def build_images():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    boot16 = os.path.join(BUILDDIR, "boot16.bin")
    program = os.path.join(BUILDDIR, "misc21.com")
    aonly = os.path.join(BUILDDIR, "aonly.txt")
    with open(aonly, "wb") as f:
        f.write(b"DRIVEOK")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot16])
    run_cmd(["nasm", '-DBOOT_FILE="MISC21  COM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    child = os.path.join(BUILDDIR, "ah0child.com")
    run_cmd(["nasm", "-f", "bin", "tests/programs/misc21.asm", "-o", program])
    run_cmd(["nasm", "-f", "bin", "tests/programs/ah0child.asm", "-o", child])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, FLOPPY_IMG,
             program, child, aonly])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", boot16, KERNEL,
             HD_IMG])


def main():
    build_images()
    output = run_serial_image(FLOPPY_IMG, TIMEOUT, extra_args=("-drive", f"file={HD_IMG},format=raw,if=ide,index=0,media=disk"))
    passed = check_markers(
        output,
        required=("PASS: MISC21 RETCODE", "PASS: MISC21 BOOT", "PASS: MISC21 PARSE", "PASS: MISC21 INT2F",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="misc21 QEMU serial output")
    if not passed:
        sys.exit(1)
    print("\nINT 21h conventions test passed.")


if __name__ == "__main__":
    main()
