#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "findattr.img")
KERNEL = os.path.join(BUILDDIR, "findattr_kernel.bin")
TIMEOUT = 8


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def set_root_attr(image_path, dos_name, attr):
    name = dos_name.encode("ascii")
    with open(image_path, "r+b") as f:
        image = bytearray(f.read())
        bps = int.from_bytes(image[0x0B:0x0D], "little")
        reserved = int.from_bytes(image[0x0E:0x10], "little")
        fats = image[0x10]
        root_entries = int.from_bytes(image[0x11:0x13], "little")
        fat_secs = int.from_bytes(image[0x16:0x18], "little")
        root_off = (reserved + fats * fat_secs) * bps
        for off in range(root_off, root_off + root_entries * 32, 32):
            first = image[off]
            if first == 0:
                break
            if first != 0xE5 and image[off:off + 11] == name:
                image[off + 11] = attr
                f.seek(0)
                f.write(image)
                return
    print(f"Missing root entry {dos_name}", file=sys.stderr)
    sys.exit(1)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="FINDATTRCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/findattr.asm", "-o", os.path.join(BUILDDIR, "findattr.com")])
    normal = write_fixture("normal.txt", b"normal\n")
    hidden = write_fixture("hidden.txt", b"hidden\n")
    system = write_fixture("system.txt", b"system\n")
    volume = write_fixture("volume.lbl", b"label\n")
    subfile = write_fixture("subfile.dat", b"subdir\n")
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "findattr.com"),
        normal,
        hidden,
        system,
        volume,
        f"SUBDIR:{subfile}",
    ])
    set_root_attr(IMG, "HIDDEN  TXT", 0x22)
    set_root_attr(IMG, "SYSTEM  TXT", 0x24)
    set_root_attr(IMG, "VOLUME  LBL", 0x08)


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def main():
    build_image()
    output = run_qemu()
    if not check_markers(output, required=("PASS: FINDATTR", "Program exited, code=00")):
        sys.exit(1)
    print("\nFind attribute test passed.")


if __name__ == "__main__":
    main()
