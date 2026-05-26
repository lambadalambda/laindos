#!/usr/bin/env python3
import os
import signal
import subprocess
import sys
import tempfile

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "fat16large.img")
KERNEL = os.path.join(BUILDDIR, "fat16large_kernel.bin")
TIMEOUT = 15
MARKER_OFF = 0x02000010
MARKER = b"FAT16-BIG-LBA!\0\0"


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "fat16large_boot.bin")
    fatbig = os.path.join(BUILDDIR, "fatbig.com")
    bigdat = os.path.join(BUILDDIR, "big.dat")
    run(["nasm", "-f", "bin", "src/boot16.asm", "-o", boot])
    run(["nasm", '-DBOOT_FILE="FATBIG  COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run(["nasm", "-f", "bin", "src/fatbig.asm", "-o", fatbig])
    with open(bigdat, "wb") as f:
        f.truncate(MARKER_OFF + len(MARKER))
        f.seek(MARKER_OFF)
        f.write(MARKER)
    run(["python3", "scripts/mkimage.py", "--format=hd96m", boot, KERNEL, IMG, fatbig, bigdat])


def run_qemu():
    proc = subprocess.Popen(
        [
            QEMU,
            "-drive", f"file={IMG},format=raw",
            "-boot", "order=c",
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
    err = stderr.decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in [
        "MiniDOS booted",
        "PASS: FAT16BIG",
        "Program exited, code=00",
        "HALT",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nLarge FAT16 read test passed.")


if __name__ == "__main__":
    main()
