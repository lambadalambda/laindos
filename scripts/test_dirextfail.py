#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "dirextfail.img")
KERNEL = os.path.join(BUILDDIR, "dirextfail_kernel.bin")
TIMEOUT = 8


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", "-DTEST_DIR_EXT_ZERO_FAIL", '-DBOOT_FILE="DIREXTFACOM"',
        "-f", "bin", "src/kernel.asm", "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "tests/programs/dirextfail.asm", "-o", os.path.join(BUILDDIR, "dirextfa.com")])
    fillers = []
    for i in range(14):
        fillers.append(write_fixture(f"dfill{i:02d}.dat", f"filler {i:02d}\n".encode("ascii")))
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "dirextfa.com"),
        *[f"FULLDIR:{path}" for path in fillers],
    ])


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def get_fat12(fat, cluster):
    off = cluster + (cluster >> 1)
    if cluster & 1:
        return ((fat[off] >> 4) | (fat[off + 1] << 4)) & 0xFFF
    return (fat[off] | ((fat[off + 1] & 0x0F) << 8)) & 0xFFF


def cluster_chain(fat, cluster):
    chain = []
    seen = set()
    while 2 <= cluster < 0xFF8:
        if cluster in seen:
            raise RuntimeError(f"cluster loop at {cluster}")
        seen.add(cluster)
        chain.append(cluster)
        cluster = get_fat12(fat, cluster)
    return chain


def iter_entries(directory):
    for off in range(0, len(directory), 32):
        first = directory[off]
        if first == 0:
            break
        if first != 0xE5:
            yield directory[off:off + 32]


def find_entry(directory, name):
    for entry in iter_entries(directory):
        if entry[0:11] == name:
            return entry
    return None


def verify_disk():
    with open(IMG, "rb") as f:
        image = f.read()
    bps = struct.unpack_from("<H", image, 0x0B)[0]
    spc = image[0x0D]
    reserved = struct.unpack_from("<H", image, 0x0E)[0]
    fats = image[0x10]
    root_entries = struct.unpack_from("<H", image, 0x11)[0]
    fat_secs = struct.unpack_from("<H", image, 0x16)[0]
    root_start = reserved + fats * fat_secs
    root_secs = (root_entries * 32 + bps - 1) // bps
    fat = image[reserved * bps:(reserved + fat_secs) * bps]
    root = image[root_start * bps:(root_start + root_secs) * bps]
    full = find_entry(root, b"FULLDIR    ")
    if full is None or full[11] & 0x10 == 0:
        print("  FAIL: FULLDIR missing")
        return False
    cluster = struct.unpack_from("<H", full, 26)[0]
    chain = cluster_chain(fat, cluster)
    if len(chain) != 1:
        print(f"  FAIL: FULLDIR chain was extended after failed write: {chain}")
        return False
    print("  PASS: failed extension did not persist FAT link")
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: DIREXTFAIL", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if not verify_disk():
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nDirectory extension rollback test passed.")


if __name__ == "__main__":
    main()
