#!/usr/bin/env python3
import sys
import os
from testlib import run_qemu_capture

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

    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={DISK_IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    failed = False

    for marker in EXPECTED:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True

    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    else:
        print("\nAll tests passed.")
        sys.exit(0)


if __name__ == "__main__":
    test_boot()
