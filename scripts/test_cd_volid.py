#!/usr/bin/env python3
"""CD volume-label FindFirst answers from the ISO9660 volume identifier.

MSCDEX serves an exclusive volume-label search (attribute 0x08) from the
PVD volume id, ignoring the pattern — programs pass a bare "D:\\" path.
Red Alert tells its discs apart this way ("CD1"/"CD2"): without the
label it loops at the "PLEASE INSERT A RED ALERT CD" dialog even with
the disc in the drive. Also pins that normal searches stay free of the
synthetic label and that unlabeled FAT volumes still report no match.
"""
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_volid")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdvolid.com")
HELLO = os.path.join(WORKDIR, "hello.txt")
IMG = os.path.join(WORKDIR, "cd_volid.img")
ISO = os.path.join(WORKDIR, "cd_volid.iso")
TIMEOUT = 15


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(HELLO, "wb") as f:
        f.write(b"Hello from LainDOS CD volume-label test.\r\n")
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"HELLO.TXT={HELLO}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDVOLID COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdvolid.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_artifacts()
    output = run_serial_image(IMG, TIMEOUT, extra_args=("-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on"))
    ok = check_markers(
        output,
        required=("PASS: CDVOLID", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD volume-label QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nCD volume-label test passed.")


if __name__ == "__main__":
    main()
