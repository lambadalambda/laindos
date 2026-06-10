#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import run_serial_image, run_cmd, build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "ems.img")
KERNEL = os.path.join(BUILDDIR, "ems_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    test_com = os.path.join(BUILDDIR, "emstest.com")
    kernel_defines = ['-DBOOT_FILE="EMSTEST COM"', "-DENABLE_EMS=1"]
    frame_seg = os.environ.get("LAINDOS_EMS_FRAME_SEG")
    if frame_seg:
        kernel_defines.append(f"-DEMS_FRAME_SEG={frame_seg}")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm", *kernel_defines, "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/emstest.asm", "-o", test_com])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, test_com])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: EMS", "Program exited, code=00", "HALT"]:
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
    print("\nEMS API test passed.")


if __name__ == "__main__":
    main()
