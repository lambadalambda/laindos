#!/usr/bin/env python3
import os
import socket
import subprocess
import sys
import time
from testlib import run_cmd, build_dir, finish_qemu, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "devnames.img")
KERNEL = os.path.join(BUILDDIR, "devnames_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "devnames.sock")


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="DEVNAMESCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/devnames.asm", "-o", os.path.join(BUILDDIR, "devnames.com")])
    with open(os.path.join(BUILDDIR, "nulfile.dat"), "wb") as f:
        f.write(b"REAL")
    with open(os.path.join(BUILDDIR, "console.dat"), "wb") as f:
        f.write(b"LONG")
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "devnames.com"),
        os.path.join(BUILDDIR, "nulfile.dat"),
        os.path.join(BUILDDIR, "console.dat"),
    ])


def send_monitor_key(sock, key):
    sock.sendall(f"sendkey {key}\n".encode())
    time.sleep(0.15)


def send_key_after_ready(output_chunks):
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
    if wait_for_output(output_chunks, "READY: DEVREAD"):
        send_monitor_key(sock, "z")
        time.sleep(0.1)
        send_monitor_key(sock, "ret")
    sock.close()


def root_has_name(raw_name):
    with open(IMG, "rb") as f:
        data = f.read()
    bytes_per_sector = int.from_bytes(data[11:13], "little")
    reserved = int.from_bytes(data[14:16], "little")
    fats = data[16]
    root_entries = int.from_bytes(data[17:19], "little")
    sectors_per_fat = int.from_bytes(data[22:24], "little")
    root_start = (reserved + fats * sectors_per_fat) * bytes_per_sector
    for index in range(root_entries):
        entry = data[root_start + index * 32:root_start + (index + 1) * 32]
        if not entry or entry[0] == 0:
            return False
        if entry[0] == 0xE5:
            continue
        if entry[:11] == raw_name:
            return True
    return False


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
        send_key_after_ready(stdout_chunks)
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
    for marker in [
        "PASS: CONWRITE",
        "READY: DEVREAD",
        "PASS: DEVNAMES",
        "Program exited, code=00",
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
    if root_has_name(b"NUL        "):
        print("  FAIL: real NUL file was created")
        failed = True
    else:
        print("  PASS: no real NUL file created")
    if root_has_name(b"CONSOLE DAT"):
        print("  PASS: CONSOLE.DAT on disk")
    else:
        print("  FAIL: CONSOLE.DAT missing from disk")
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nDevice name test passed.")


if __name__ == "__main__":
    main()
