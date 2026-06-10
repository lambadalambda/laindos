#!/usr/bin/env python3
import os
import subprocess
import sys
from testlib import run_cmd, build_dir, run_qemu_capture


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "ffname.img")
KERNEL = os.path.join(BUILDDIR, "ffname_kernel.bin")
TIMEOUT = 8


def set_root_entry_bytes(image_path, dos_name, new_bytes, attr):
    old_name = dos_name.encode("ascii")
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
            if first != 0xE5 and image[off:off + 11] == old_name:
                image[off:off + 11] = new_bytes
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
        "nasm", '-DBOOT_FILE="FFNAME  COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/ffname.asm", "-o", os.path.join(BUILDDIR, "ffname.com")])
    e5_path = os.path.join(BUILDDIR, "normal.txt")
    with open(e5_path, "wb") as f:
        f.write(b"e5 test\n")
    nul_path = os.path.join(BUILDDIR, "nulfile.txt")
    with open(nul_path, "wb") as f:
        f.write(b"nul test\n")
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "ffname.com"),
        e5_path,
        nul_path,
    ])
    set_root_entry_bytes(IMG, "NORMAL  TXT", b"NORMA\xe5L TXT", 0x20)
    set_root_entry_bytes(IMG, "NULFILE TXT", b"NUL\x00FILETXT", 0x20)


def main():
    build_image()
    output, _ = run_qemu_capture([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    failed = False
    for marker in ["PASS: FFNAME", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC "]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFindFirst filename sanitization test passed.")


if __name__ == "__main__":
    main()
