#!/usr/bin/env python3
import os
import signal
import subprocess
import sys
import tempfile

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "fat16.img")
KERNEL = os.path.join(BUILDDIR, "fat16_kernel.bin")
TIMEOUT = 10


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
    boot = os.path.join(BUILDDIR, "boot16.bin")
    memtest = os.path.join(BUILDDIR, "memtest.exe")
    run(["nasm", "-f", "bin", "src/boot16.asm", "-o", boot])
    run(["nasm", "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run(["nasm", "-f", "bin", "src/memtest.asm", "-o", memtest])
    with tempfile.TemporaryDirectory(dir=BUILDDIR) as filler_dir:
        fillers = []
        for i in range(224):
            path = os.path.join(filler_dir, f"f{i:03d}.dat")
            with open(path, "wb") as f:
                f.write(b"x")
            fillers.append(path)
        run(["python3", "scripts/mkimage.py", "--format=hd32m", boot, KERNEL, IMG, *fillers, memtest])


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
        "PASS: MEM",
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
    print("\nFAT16 boot test passed.")


if __name__ == "__main__":
    main()
