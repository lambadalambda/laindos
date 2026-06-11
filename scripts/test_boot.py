#!/usr/bin/env python3
import sys
import os
from testlib import check_markers, run_serial_image

QEMU = "qemu-system-i386"
DISK_IMG = os.path.join(os.path.dirname(__file__), "..", "build", "disk.img")
TIMEOUT = 10

EXPECTED = [
    "LainDOS booted",
    "Conventional memory:",
    "KB",
    "INT 20h/21h installed",
    "PASS: MEM",
    "Program exited, code=",
    "HALT",
]


def test_boot():
    if not os.path.exists(DISK_IMG):
        print("FAIL: disk image not found, run 'mise run build' first")
        sys.exit(1)

    output = run_serial_image(DISK_IMG, TIMEOUT, extra_args=("-snapshot",))
    if not check_markers(output, required=EXPECTED,
                         forbidden=()):
        sys.exit(1)
    else:
        print("\nAll tests passed.")
        sys.exit(0)


if __name__ == "__main__":
    test_boot()
