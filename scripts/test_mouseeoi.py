#!/usr/bin/env python3
import os
import socket
import sys
import time
from testlib import (build_dir, chunks_contain, finish_qemu, run_cmd,
                     start_qemu, wait_for_output)

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "mouseeoi.img")
KERNEL = os.path.join(BUILDDIR, "mouseeoi_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "mouseeoi.sock")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    program = os.path.join(BUILDDIR, "mouseeoi.com")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="MOUSEEOICOM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/mouseeoi.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, program])


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
    if not wait_for_output(stdout_chunks, "READY: MOUSEEOI", timeout=TIMEOUT,
                           stop_markers=()):
        output, timed_out = finish_qemu(proc, stdout_chunks, stderr_chunks,
                                        threads, timeout=1)
        sock.close()
        return output, timed_out
    deadline = time.monotonic() + TIMEOUT
    while time.monotonic() < deadline and not chunks_contain(
            stdout_chunks, ("PASS: MOUSEEOI", "FAIL:")):
        sock.sendall(b"mouse_move 40 0\n")
        time.sleep(0.1)
    sock.close()
    return finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=3,
                       stop_markers=("HALT", "PASS: MOUSEEOI"))


def main():
    build_image()
    output, timed_out = run_qemu()
    failed = timed_out
    if timed_out:
        print("  FAIL: timed out")
    if "PASS: MOUSEEOI" in output:
        print("  PASS: found 'PASS: MOUSEEOI'")
    else:
        print("  FAIL: missing 'PASS: MOUSEEOI'")
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
    print("\nMouse EOI ordering test passed.")


if __name__ == "__main__":
    main()
