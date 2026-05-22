#!/usr/bin/env python3
import os
import signal
import socket
import subprocess
import sys
import tempfile
import time

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "consoletest.img")
KERNEL = os.path.join(BUILDDIR, "consoletest_kernel.bin")
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-consoletest.sock")


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
        "nasm", '-DBOOT_FILE="CONSOLE COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/consoletest.asm", "-o", os.path.join(BUILDDIR, "console.com")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "console.com"),
    ])


def send_keys():
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
    for key in ["a", "b", "c", "d", "x", "y", "backspace", "z", "ret"]:
        sock.sendall(f"sendkey {key}\n".encode())
        time.sleep(0.2)
    sock.close()


def run_qemu():
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    proc = subprocess.Popen(
        [
            QEMU,
            "-drive", f"file={IMG},format=raw,if=floppy",
            "-boot", "order=a",
            "-serial", "stdio",
            "-monitor", f"unix:{MONITOR},server,nowait",
            "-nographic",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    time.sleep(3)
    send_keys()
    try:
        stdout, stderr = proc.communicate(timeout=8)
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
    for marker in ["READY: CONSOLE", "PASS: CONSOLE", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH=01", "INT 21h AH=06", "INT 21h AH=07", "INT 21h AH=0A"]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nConsole API test passed.")


if __name__ == "__main__":
    main()
