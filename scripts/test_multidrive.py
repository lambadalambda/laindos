#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, run_cmd, run_qemu_capture


QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
FLOPPY_IMG = os.path.join(BUILDDIR, "multidrive_floppy.img")
HD_IMG = os.path.join(BUILDDIR, "multidrive_hd.img")
KERNEL = os.path.join(BUILDDIR, "multidrive_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
BOOT16 = os.path.join(BUILDDIR, "boot16.bin")
PROGRAM = os.path.join(BUILDDIR, "multidrv.com")
AONLY = os.path.join(BUILDDIR, "aonly.txt")
HDONLY = os.path.join(BUILDDIR, "hdonly.txt")
TIMEOUT = 12


def build_images():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(AONLY, "wb") as f:
        f.write(b"DRIVEOK")
    with open(HDONLY, "wb") as f:
        f.write(b"DRIVEOK")
    run_cmd(["nasm", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", "-f", "bin", "src/boot16.asm", "-o", BOOT16])
    run_cmd([
        "nasm", '-DBOOT_FILE="MULTIDRVCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/multidrive.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, FLOPPY_IMG, PROGRAM, AONLY])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT16, KERNEL, HD_IMG, HDONLY])


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={FLOPPY_IMG},format=raw,if=floppy",
        "-drive", f"file={HD_IMG},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def main():
    build_images()
    output = run_qemu()
    failed = False
    for marker in ["PASS: MULTIDRIVE", "Program exited, code=00", "HALT"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nMulti-drive test passed.")


if __name__ == "__main__":
    main()
