#!/usr/bin/env python3
import os
import socket
import subprocess
import sys
import time
from testlib import build_dir, finish_qemu, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "linebuftest.img")
KERNEL = os.path.join(BUILDDIR, "linebuftest_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "linebuftest.sock")


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
        "nasm", '-DBOOT_FILE="LINEBUF COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "tests/programs/linebuf.asm", "-o", os.path.join(BUILDDIR, "linebuf.com")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "linebuf.com"),
    ])


def send_keys(keys):
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
    for key in keys:
        sock.sendall(f"sendkey {key}\n".encode())
        time.sleep(0.2)
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
        if not wait_for_output(stdout_chunks, "READY: LINEBUF", timeout=10, stop_markers=()):
            raise TimeoutError("timed out waiting for READY")
        send_keys(["x", "z", "ret"])
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
    failed = False
    for marker in ["PASS: LINEBUF", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    if "FAIL:" in output:
        for line in output.splitlines():
            if "FAIL:" in line:
                print(f"  FAIL: {line.strip()}")
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nLine buffer max=0/2 test passed.")


if __name__ == "__main__":
    main()
