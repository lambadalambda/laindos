#!/usr/bin/env python3
import os
import socket
import subprocess
import sys
import time
from testlib import build_dir, check_markers, chunks_contain, finish_qemu, run_cmd, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "flushread.img")
KERNEL = os.path.join(BUILDDIR, "flushread_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "flushread.sock")


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="FLUSHR  COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/flushread.asm", "-o", os.path.join(BUILDDIR, "flushr.com")])
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "flushr.com"),
    ])


def send_key(sock, key):
    sock.sendall(f"sendkey {key}\n".encode())


def send_keys(stdout_chunks):
    deadline = time.time() + 8
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    while True:
        try:
            sock.connect(MONITOR)
            break
        except OSError:
            if time.time() > deadline:
                raise
            time.sleep(0.1)
    sock.recv(4096)
    send_key(sock, "x")
    time.sleep(1.4)
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline and not chunks_contain(stdout_chunks, ("PASS: FLUSHREAD", "FAIL:")):
        send_key(sock, "y")
        time.sleep(0.7)
    sock.close()


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
    try:
        if not wait_for_output(stdout_chunks, "READY: FLUSHREAD", timeout=15, stop_markers=()):
            raise TimeoutError("timed out waiting for 'READY: FLUSHREAD'")
        send_keys(stdout_chunks)
    except Exception:
        proc.kill()
        proc.wait()
        for thread in threads:
            thread.join(timeout=1)
        raise
    output, _ = finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=8, stop_markers=("HALT", "Program exited, code=00"))
    return output


def main():
    build_image()
    output = run_qemu()
    if not check_markers(output, required=("READY: FLUSHREAD", "PASS: FLUSHREAD", "Program exited, code=00"),
                         forbidden=("FAIL:", "EXC ", "INT 21h AH=0C")):
        sys.exit(1)
    print("\nFlush-and-read test passed.")


if __name__ == "__main__":
    main()
