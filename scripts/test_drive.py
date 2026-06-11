#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import build_dir, run_cmd, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
HD_IMG = os.path.join(BUILDDIR, "drivetest_hd.img")
FLOPPY_IMG = os.path.join(BUILDDIR, "drivetest_floppy.img")
KERNEL = os.path.join(BUILDDIR, "drivetest_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
DRIVE_COM = os.path.join(BUILDDIR, "drive.com")
TIMEOUT = 10


def build_artifacts():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="DRIVE   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/drivetest.asm", "-o", DRIVE_COM])


def build_image(output_path, fmt=None):
    cmd = ["python3", "scripts/mkimage.py"]
    if fmt:
        cmd.append(f"--format={fmt}")
    cmd.extend([BOOT, KERNEL, output_path, DRIVE_COM])
    run_cmd(cmd)


def run_qemu(image_path, hard_disk):
    if hard_disk:
        return run_serial_image(image_path, TIMEOUT, drive_opts="", boot_order="c")
    return run_serial_image(image_path, TIMEOUT)


def check_output(label, output):
    failed = False
    normalized = output.replace("Program exited, code=0.\r\n0", "Program exited, code=00")
    normalized = normalized.replace("Program exited, code=0.\n0", "Program exited, code=00")
    for marker in ["PASS: DRIVE", "Program exited, code=00"]:
        if marker in output or marker in normalized:
            print(f"  PASS: {label} found '{marker}'")
        else:
            print(f"  FAIL: {label} missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: {label} unexpected '{marker}'")
            failed = True
    if failed:
        print(f"\n--- QEMU serial output ({label}) ---")
        print(output)
        print("--- end ---")
    return failed


def main():
    build_artifacts()
    build_image(HD_IMG, "hd10m")
    build_image(FLOPPY_IMG)
    failed = check_output("hard disk", run_qemu(HD_IMG, True))
    failed |= check_output("floppy", run_qemu(FLOPPY_IMG, False))
    if failed:
        sys.exit(1)
    print("\nDrive API test passed.")


if __name__ == "__main__":
    main()
