#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
TIMEOUT = 8


def build_image(label, image_format=None, boot_source="src/boot.asm"):
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, f"{label}_boot.bin")
    kernel = os.path.join(BUILDDIR, f"{label}_kernel.bin")
    program = os.path.join(BUILDDIR, "diskfree.com")
    img = os.path.join(BUILDDIR, f"{label}.img")
    run_cmd(["nasm", "-f", "bin", boot_source, "-o", boot])
    run_cmd([
        "nasm", '-DBOOT_FILE="DISKFREECOM"', "-f", "bin", "src/kernel.asm",
        "-o", kernel,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/diskfree.asm", "-o", program])
    mkimage_cmd = ["python3", "scripts/mkimage.py"]
    if image_format:
        mkimage_cmd.append(f"--format={image_format}")
    mkimage_cmd.extend([boot, kernel, img, program])
    run_cmd(mkimage_cmd)
    return img


def run_qemu(img, drive_opts="if=floppy", boot_order="a", timeout=TIMEOUT):
    drive_arg = f"file={img},format=raw"
    if drive_opts:
        drive_arg = f"{drive_arg},{drive_opts}"
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", drive_arg,
        "-boot", f"order={boot_order}",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], timeout)
    return output


def run_case(name, label, **kwargs):
    print(f"\n{name}")
    img = build_image(label, kwargs.get("image_format"), kwargs.get("boot_source", "src/boot.asm"))
    output = run_qemu(
        img,
        kwargs.get("drive_opts", "if=floppy"),
        kwargs.get("boot_order", "a"),
        kwargs.get("timeout", TIMEOUT),
    )
    return check_markers(
        output,
        required=("PASS: DISKFREE", "Program exited, code=00", "HALT"),
        output_label=f"{name} QEMU serial output",
    )


def main():
    failed = not run_case("FAT12 floppy disk free", "fat12")
    if not run_case(
        "FAT16 hard disk free",
        "fat16",
        image_format="hd32m",
        boot_source="src/boot16.asm",
        drive_opts="",
        boot_order="c",
        timeout=12,
    ):
        failed = True
    if failed:
        sys.exit(1)
    print("\nDisk free tests passed.")


if __name__ == "__main__":
    main()
