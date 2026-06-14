#!/usr/bin/env python3
import os
import socket
import subprocess
import sys
import time
from testlib import build_dir, check_markers, finish_qemu, run_cmd, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "envpath.img")
KERNEL = os.path.join(BUILDDIR, "envpath_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "envpath.sock")


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["python3", "scripts/build_shell_com.py", os.path.join(BUILDDIR, "shell.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/envtest.asm", "-o", os.path.join(BUILDDIR, "envtest.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/pathrun.asm", "-o", os.path.join(BUILDDIR, "pathrun.com")])
    run_cmd([
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


def send_keys(output_chunks):
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
    if not wait_for_output(output_chunks, "A:\\>", timeout=15, stop_markers=()):
        raise TimeoutError("timed out waiting for 'A:\\>'")
    for command in ["envtest", "md work", "cd work", "pathrun", "exit"]:
        send_text(sock, command)
        send_monitor_key(sock, "ret")
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
    if not check_markers(output, required=("PASS: ENVTEST", "PASS: PATHRUN", "Program exited, code=00"),
                         forbidden=("FAIL:", "EXC ", "INT 21h AH=", "Bad command or file name")):
        sys.exit(1)
    print("\nEnvironment/PATH test passed.")


if __name__ == "__main__":
    main()
