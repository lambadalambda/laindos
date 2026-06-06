#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

BUILDDIR = build_dir()
FLOPPY_IMG = os.path.join(BUILDDIR, "drivedata_floppy.img")
HD_IMG = os.path.join(BUILDDIR, "drivedata_hd.img")
KERNEL = os.path.join(BUILDDIR, "drivedata_kernel.bin")
BOOT_FLOPPY = os.path.join(BUILDDIR, "drivedata_boot.bin")
BOOT_HD = os.path.join(BUILDDIR, "drivedata_boot16.bin")
PROGRAM = os.path.join(BUILDDIR, "drivedat.com")
TIMEOUT = 10


def build_artifacts():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT_FLOPPY])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT_HD])
    run_cmd(["nasm", '-DBOOT_FILE="DRIVEDATCOM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/drivedata.asm", "-o", PROGRAM])


def build_image(output_path, boot, fmt=None):
    cmd = ["python3", "scripts/mkimage.py"]
    if fmt:
        cmd.append(f"--format={fmt}")
    cmd.extend([boot, KERNEL, output_path, PROGRAM])
    run_cmd(cmd)


def run_image(image_path, hard_disk=False):
    drive_arg = f"file={image_path},format=raw"
    if not hard_disk:
        drive_arg += ",if=floppy"
    boot_order = "c" if hard_disk else "a"
    output, _ = run_qemu_capture([
        "qemu-system-i386",
        "-drive", drive_arg,
        "-boot", f"order={boot_order}",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def check_output(label, output):
    return check_markers(
        output,
        required=("PASS: DRIVEDATA", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=1B", "INT 21h AH=1C"),
        output_label=f"QEMU serial output ({label})",
    )


def main():
    build_artifacts()
    build_image(FLOPPY_IMG, BOOT_FLOPPY)
    build_image(HD_IMG, BOOT_HD, "hd32m")
    ok = check_output("floppy", run_image(FLOPPY_IMG))
    ok &= check_output("hard disk", run_image(HD_IMG, hard_disk=True))
    if not ok:
        sys.exit(1)
    print("\nDrive data test passed.")


if __name__ == "__main__":
    main()
