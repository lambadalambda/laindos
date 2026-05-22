#!/usr/bin/env python3
import os
import signal
import subprocess
import sys

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "ovltest.img")
KERNEL = os.path.join(BUILDDIR, "ovltest_kernel.bin")
TIMEOUT = 8


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
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="OVLTEST COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/ovltest.asm", "-o", os.path.join(BUILDDIR, "ovltest.com")])
    run(["nasm", "-f", "bin", "src/overlay.asm", "-o", os.path.join(BUILDDIR, "overlay.exe")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "ovltest.com"),
        os.path.join(BUILDDIR, "overlay.exe"),
    ])


def run_qemu():
    proc = subprocess.Popen(
        [
            QEMU,
            "-drive", f"file={IMG},format=raw,if=floppy",
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
    err = stderr.decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def main():
    build_image()
    output = run_qemu()
    failed = False

    if "PASS: OVERLAY" in output:
        print("  PASS: found 'PASS: OVERLAY'")
    else:
        print("  FAIL: missing 'PASS: OVERLAY'")
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

    print("\nOverlay load test passed.")


if __name__ == "__main__":
    main()
