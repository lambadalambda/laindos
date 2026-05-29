#!/usr/bin/env python3
import os
import struct
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "findtime.img")
KERNEL = os.path.join(BUILDDIR, "findtime_kernel.bin")
TIMEOUT = 8
ENTRY_NAME = b"TIMECHK " + b"DAT"
SET_TIME = 0x1234
SET_DATE = 0x5678


def build_image():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "FINDTIMECOM", "tests/programs/findtime.asm", "findtime.com")


def verify_disk_time():
    with open(IMG, "rb") as f:
        image = f.read()
    bps = struct.unpack_from("<H", image, 0x0B)[0]
    reserved = struct.unpack_from("<H", image, 0x0E)[0]
    fats = image[0x10]
    root_entries = struct.unpack_from("<H", image, 0x11)[0]
    fat_secs = struct.unpack_from("<H", image, 0x16)[0]
    root_start = reserved + fats * fat_secs
    root_secs = (root_entries * 32 + bps - 1) // bps
    root = image[root_start * bps:(root_start + root_secs) * bps]
    for off in range(0, len(root), 32):
        first = root[off]
        if first == 0:
            break
        if first != 0xE5 and root[off:off + 11] == ENTRY_NAME:
            time_word = struct.unpack_from("<H", root, off + 22)[0]
            date_word = struct.unpack_from("<H", root, off + 24)[0]
            if time_word != SET_TIME or date_word != SET_DATE:
                print(f"  FAIL: disk timestamp mismatch time={time_word:04X} date={date_word:04X}")
                return False
            print("  PASS: disk image contains set file timestamp")
            return True
    print("  FAIL: TIMECHK.DAT missing from disk image")
    return False


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    markers_ok = check_markers(output, required=("PASS: FINDTIME", "Program exited, code=00", "HALT"))
    disk_ok = verify_disk_time()
    if not markers_ok or not disk_ok:
        sys.exit(1)
    print("\nFind time test passed.")


if __name__ == "__main__":
    main()
