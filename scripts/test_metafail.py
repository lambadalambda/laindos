#!/usr/bin/env python3
import os
import struct
import sys

from fatlib import FatImage, entry_cluster, entry_size
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "metafail.img")
KERNEL = os.path.join(BUILDDIR, "metafail_kernel.bin")
TIMEOUT = 10


def build_image():
    build_nasm_test_image(
        BUILDDIR,
        IMG,
        KERNEL,
        "METAFAILCOM",
        "tests/programs/metafail.asm",
        "metafail.com",
        kernel_defines=("-DTEST_FLUSH_DIR_SLOT_FAIL", "-DTEST_FLUSH_DIR_SLOT_FAIL_AFTER=2"),
    )


def verify_disk():
    img = FatImage.from_file(IMG)
    entry = img.find("METAFAIL.DAT")
    if entry is None:
        print("  FAIL: METAFAIL.DAT missing")
        return False
    if entry_size(entry) != 1:
        print(f"  FAIL: METAFAIL.DAT size {entry_size(entry)} != 1")
        return False
    if entry_cluster(entry) < 2:
        print(f"  FAIL: METAFAIL.DAT cluster {entry_cluster(entry)} invalid")
        return False
    data = img.read_file("METAFAIL.DAT")
    if data != b"\xA7":
        print(f"  FAIL: METAFAIL.DAT data {data!r} != b'\\xA7'")
        return False
    time_word = struct.unpack_from("<H", entry, 22)[0]
    date_word = struct.unpack_from("<H", entry, 24)[0]
    if time_word != 0x4321 or date_word != 0x5A21:
        print(f"  FAIL: METAFAIL.DAT timestamp {time_word:04X}:{date_word:04X}")
        return False
    print("  PASS: retry persisted dirty size, cluster, data, and timestamp")
    return True


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    failed = not check_markers(
        output,
        required=("PASS: METAFAIL", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
    )
    if not verify_disk():
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nMetadata flush failure retry test passed.")


if __name__ == "__main__":
    main()
