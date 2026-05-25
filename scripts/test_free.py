#!/usr/bin/env python3
import os
import re
import signal
import subprocess
import sys

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "freetest.img")
KERNEL = os.path.join(BUILDDIR, "freetest_kernel.bin")
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
    boot = os.path.join(BUILDDIR, "boot.bin")
    free_com = os.path.join(BUILDDIR, "free.com")
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", boot])
    run([
        "nasm", '-DBOOT_FILE="FREE    COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/free.asm", "-o", free_com])
    run(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, free_com])


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


def summary_kb(output, label):
    match = re.search(rf"{re.escape(label)}\s*(\d+)K", output)
    if not match:
        return None
    return int(match.group(1))


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in [
        "LainDOS memory report",
        "MCB  Stat Owner Block Paras KB",
        "SELF ",
        "FREE ",
        "Total managed memory:",
        "Used memory:",
        "Total free memory:",
        "Largest free block:",
        "Program exited, code=00",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH=", "Invalid MCB chain"]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    total_kb = summary_kb(output, "Total managed memory:")
    used_kb = summary_kb(output, "Used memory:")
    free_kb = summary_kb(output, "Total free memory:")
    largest_kb = summary_kb(output, "Largest free block:")
    if None in (total_kb, used_kb, free_kb, largest_kb):
        print("  FAIL: missing summary memory numbers")
        failed = True
    elif total_kb <= 0:
        print("  FAIL: total managed memory is zero")
        failed = True
    else:
        used_free_kb = used_kb + free_kb
        if total_kb < used_free_kb or total_kb > used_free_kb + 1:
            print(
                "  FAIL: summary mismatch "
                f"total={total_kb}K used={used_kb}K free={free_kb}K"
            )
            failed = True
        elif largest_kb > free_kb:
            print(
                "  FAIL: largest free block exceeds total free memory "
                f"largest={largest_kb}K free={free_kb}K"
            )
            failed = True
        else:
            print(
                "  PASS: summary memory numbers are consistent "
                f"total={total_kb}K used={used_kb}K free={free_kb}K"
            )
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFree memory report test passed.")


if __name__ == "__main__":
    main()
