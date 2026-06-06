#!/usr/bin/env python3
import os
import socket
import subprocess
import sys
import time
from testlib import build_dir, finish_qemu, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "mouseratio.img")
KERNEL = os.path.join(BUILDDIR, "mouseratio_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "mouseratio.sock")
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
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="MOUSERATEXE"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "tests/programs/mouseratio.asm", "-o", os.path.join(BUILDDIR, "mouserat.exe")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "mouserat.exe"),
    ])


def connect_monitor():
    deadline = time.monotonic() + 5
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    while True:
        try:
            sock.connect(MONITOR)
            sock.recv(4096)
            return sock
        except OSError:
            if time.monotonic() > deadline:
                raise
            time.sleep(0.05)


def run_qemu():
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-nographic",
    ])
    sock = connect_monitor()
    for marker, commands in [
        ("READY: MOUSERATIO 1", [b"mouse_move 0 0\n", b"mouse_move 40 0\n"]),
        ("READY: MOUSERATIO 2", [b"mouse_move 0 0\n", b"mouse_move 40 0\n"]),
        ("READY: MOUSERATIO EDGE", [b"mouse_move -40 -40\n"]),
        ("READY: MOUSERATIO MAXEDGE", [b"mouse_move 40 40\n"]),
    ]:
        if not wait_for_output(stdout_chunks, marker, timeout=TIMEOUT, stop_markers=()):
            output, timed_out = finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=1)
            sock.close()
            return output, timed_out
        for command in commands:
            sock.sendall(command)
            time.sleep(0.05)
    sock.close()
    return finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=TIMEOUT)


def main():
    build_image()
    output, timed_out = run_qemu()
    failed = timed_out
    if timed_out:
        print("  FAIL: timed out")
    if "PASS: MOUSERATIO" in output:
        print("  PASS: found 'PASS: MOUSERATIO'")
    else:
        print("  FAIL: missing 'PASS: MOUSERATIO'")
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
    print("\nMouse ratio test passed.")


if __name__ == "__main__":
    main()
