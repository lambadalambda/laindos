#!/usr/bin/env python3
import os
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "envpath.img")
KERNEL = os.path.join(BUILDDIR, "envpath_kernel.bin")
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-envpath.sock")


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
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/shell.asm", "-o", os.path.join(BUILDDIR, "shell.com")])
    run(["nasm", "-f", "bin", "src/envtest.asm", "-o", os.path.join(BUILDDIR, "envtest.com")])
    run(["nasm", "-f", "bin", "src/pathrun.asm", "-o", os.path.join(BUILDDIR, "pathrun.com")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "shell.com"),
        os.path.join(BUILDDIR, "envtest.com"),
        f"BIN:{os.path.join(BUILDDIR, 'pathrun.com')}",
    ])


def send_monitor_key(sock, key):
    sock.sendall(f"sendkey {key}\n".encode())
    time.sleep(0.15)


def send_text(sock, text):
    keymap = {" ": "spc", "\\": "backslash", ".": "dot"}
    for ch in text:
        send_monitor_key(sock, keymap.get(ch, ch.lower()))


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
    for command in ["envtest", "md work", "cd work", "pathrun", "exit"]:
        send_text(sock, command)
        send_monitor_key(sock, "ret")
    sock.close()


def read_stream(stream, chunks):
    while True:
        data = os.read(stream.fileno(), 1024)
        if not data:
            return
        chunks.append(data)


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
    stdout_chunks = []
    stderr_chunks = []
    stdout_thread = threading.Thread(target=read_stream, args=(proc.stdout, stdout_chunks), daemon=True)
    stderr_thread = threading.Thread(target=read_stream, args=(proc.stderr, stderr_chunks), daemon=True)
    stdout_thread.start()
    stderr_thread.start()
    time.sleep(3)
    try:
        send_keys()
    except Exception:
        proc.kill()
        proc.wait()
        stdout_thread.join(timeout=1)
        stderr_thread.join(timeout=1)
        raise
    try:
        proc.wait(timeout=8)
    except subprocess.TimeoutExpired:
        proc.send_signal(signal.SIGTERM)
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
    stdout_thread.join(timeout=1)
    stderr_thread.join(timeout=1)
    output = b"".join(stdout_chunks).decode("utf-8", errors="replace")
    err = b"".join(stderr_chunks).decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: ENVTEST", "PASS: PATHRUN", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH=", "Bad command or file name"]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nEnvironment/PATH test passed.")


if __name__ == "__main__":
    main()
