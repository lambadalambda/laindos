#!/usr/bin/env python3
import os
import socket
import sys
import time
from testlib import (build_dir, check_markers, chunks_contain, finish_qemu,
                     run_cmd, run_serial_image, start_qemu, wait_for_output)

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
MONITOR = os.path.join(BUILDDIR, "mouserst.sock")
TIMEOUT = 10


def build(name, kernel_defines, program_defines):
    boot = os.path.join(BUILDDIR, "boot.bin")
    kernel = os.path.join(BUILDDIR, f"mouserst_{name}_kernel.bin")
    program = os.path.join(BUILDDIR, f"mouserst_{name}.com")
    img = os.path.join(BUILDDIR, f"mouserst_{name}.img")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="MOUSERSTCOM"', *kernel_defines, "-f", "bin",
             "src/kernel.asm", "-o", kernel])
    run_cmd(["nasm", *program_defines, "-f", "bin",
             "tests/programs/mouserst.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, kernel, img, program])
    return img


def run_absent():
    img = build("absent", ["-DTEST_MOUSE_DISABLE_PS2"], ["-DEXPECT_PRESENT=0"])
    output = run_serial_image(img, TIMEOUT)
    ok = check_markers(
        output,
        required=("PASS: MOUSERST ABSENT", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="mouserst absent QEMU serial output")
    return ok


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


def run_ratio():
    img = build("ratio", [], ["-DEXPECT_PRESENT=1"])
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        QEMU,
        "-drive", f"file={img},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-nographic",
    ])
    sock = connect_monitor()
    if wait_for_output(stdout_chunks, "READY: MOUSERST", timeout=TIMEOUT,
                       stop_markers=()):
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline and not chunks_contain(
                stdout_chunks, ("PASS: MOUSERST RATIO", "FAIL:")):
            sock.sendall(b"mouse_move 64 64\n")
            time.sleep(0.1)
    sock.close()
    output, timed_out = finish_qemu(proc, stdout_chunks, stderr_chunks, threads,
                                    timeout=3,
                                    stop_markers=("HALT", "PASS: MOUSERST RATIO"))
    ok = check_markers(
        output,
        required=("PASS: MOUSERST RATIO", "Program exited, code=00"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="mouserst ratio QEMU serial output")
    return ok and not timed_out


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    ok = run_absent()
    ok = run_ratio() and ok
    if not ok:
        sys.exit(1)
    print("\nMouse reset detection and ratio default test passed.")


if __name__ == "__main__":
    main()
