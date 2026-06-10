#!/usr/bin/env python3
import os
import socket
import sys
import time
from testlib import (build_dir, chunks_contain, finish_qemu, run_cmd,
                     start_qemu, wait_for_output)

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "ctrlc.img")
KERNEL = os.path.join(BUILDDIR, "ctrlc_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "ctrlc.sock")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="CTRLC   COM"', "-f", "bin", "src/kernel.asm",
             "-o", KERNEL])
    parts = [boot, KERNEL, IMG]
    for name in ["ctrlc", "ctrlcc", "ctrlch"]:
        out = os.path.join(BUILDDIR, f"{name}.com")
        run_cmd(["nasm", "-f", "bin", f"tests/programs/{name}.asm", "-o", out])
        parts.append(out)
    run_cmd(["python3", "scripts/mkimage.py", *parts])


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


def send_ctrl_c_until(sock, stdout_chunks, markers, deadline):
    while time.monotonic() < deadline and not chunks_contain(stdout_chunks,
                                                             markers):
        sock.sendall(b"sendkey ctrl-c\n")
        time.sleep(0.2)


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
    if wait_for_output(stdout_chunks, "READY: CTRLCC", timeout=TIMEOUT,
                       stop_markers=("FAIL:",)):
        deadline = time.monotonic() + TIMEOUT
        send_ctrl_c_until(sock, stdout_chunks, ("READY: CTRLCH", "FAIL:"),
                          deadline)
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline and not chunks_contain(
                stdout_chunks, ("PASS: CTRLC CONT", "FAIL:", "HALT")):
            sock.sendall(b"sendkey ctrl-c\n")
            time.sleep(0.1)
            sock.sendall(b"sendkey a\n")
            time.sleep(0.1)
    sock.close()
    return finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=3,
                       stop_markers=("HALT",))


def main():
    build_image()
    output, timed_out = run_qemu()
    failed = timed_out
    if timed_out:
        print("  FAIL: timed out")
    for marker in ["PASS: CTRLC KILL", "PASS: CTRLCH", "PASS: CTRLC CONT",
                   "Program exited, code=00", "HALT"]:
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
    print("\nCtrl-C INT 23h test passed.")


if __name__ == "__main__":
    main()
