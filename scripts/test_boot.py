#!/usr/bin/env python3
import subprocess
import sys
import os
import signal

QEMU = "qemu-system-i386"
DISK_IMG = os.path.join(os.path.dirname(__file__), "..", "build", "disk.img")
TIMEOUT = 10

EXPECTED = [
    "MiniDOS booted",
    "Conventional memory:",
    "KB",
    "INT 20h/21h installed",
    "PASS: HELLO.EXE",
    "Program exited, code=",
    "HALT",
]


def test_boot():
    if not os.path.exists(DISK_IMG):
        print("FAIL: disk image not found, run 'mise run build' first")
        sys.exit(1)

    proc = subprocess.Popen(
        [
            QEMU,
            "-drive", f"file={DISK_IMG},format=raw,if=floppy",
            "-boot", "order=a",
            "-serial", "stdio",
            "-monitor", "none",
            "-nographic",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        stdout, stderr = proc.communicate(timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        proc.send_signal(signal.SIGTERM)
        try:
            stdout, stderr = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout, stderr = proc.communicate()

    output = stdout.decode("utf-8", errors="replace")
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
