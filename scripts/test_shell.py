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
IMG = os.path.join(BUILDDIR, "shelltest.img")
KERNEL = os.path.join(BUILDDIR, "shelltest_kernel.bin")
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-shelltest.sock")


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
    run(["nasm", "-f", "bin", "src/hello.asm", "-o", os.path.join(BUILDDIR, "hello.com")])
    run(["nasm", "-f", "bin", "src/helloexe.asm", "-o", os.path.join(BUILDDIR, "helloexe.exe")])
    run(["nasm", "-f", "bin", "src/exectest.asm", "-o", os.path.join(BUILDDIR, "exectest.com")])
    run(["nasm", "-f", "bin", "src/keytest.asm", "-o", os.path.join(BUILDDIR, "keytest.com")])
    run(["nasm", "-f", "bin", "src/timetest.asm", "-o", os.path.join(BUILDDIR, "timetest.com")])
    run(["python3", "scripts/mktestfile.py", os.path.join(BUILDDIR, "testfile.dat")])
    run(["python3", "scripts/mksubtest.py", os.path.join(BUILDDIR, "subtest.dat")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "shell.com"),
        os.path.join(BUILDDIR, "hello.com"),
        os.path.join(BUILDDIR, "helloexe.exe"),
        os.path.join(BUILDDIR, "exectest.com"),
        os.path.join(BUILDDIR, "keytest.com"),
        os.path.join(BUILDDIR, "timetest.com"),
        os.path.join(BUILDDIR, "testfile.dat"),
        f"MIDEMO:{os.path.join(BUILDDIR, 'helloexe.exe')}",
        f"MIDEMO:{os.path.join(BUILDDIR, 'subtest.dat')}",
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
    for key in [
        "v", "e", "r", "ret",
        "c", "l", "s", "ret",
        "d", "i", "r", "ret",
        "t", "y", "p", "e", "spc", "t", "e", "s", "t", "f", "i", "l", "e", "dot", "d", "a", "t", "ret",
        "h", "e", "l", "l", "o", "ret",
        "k", "e", "y", "t", "e", "s", "t", "ret",
        "t", "i", "m", "e", "t", "e", "s", "t", "ret",
        "h", "e", "l", "l", "o", "ret",
        "h", "e", "l", "l", "o", "e", "x", "e", "ret",
        "e", "x", "e", "c", "t", "e", "s", "t", "ret",
        "m", "e", "m", "ret",
        "m", "d", "spc", "s", "h", "d", "i", "r", "ret",
        "d", "i", "r", "ret",
        "c", "d", "spc", "s", "h", "d", "i", "r", "ret",
        "c", "d", "spc", "slash", "ret",
        "c", "d", "spc", "dot", "dot", "ret",
        "r", "d", "spc", "s", "h", "d", "i", "r", "ret",
        "c", "d", "spc", "s", "h", "d", "i", "r", "ret",
        "c", "d", "spc", "m", "i", "d", "e", "m", "o", "ret",
        "d", "i", "r", "ret",
        "t", "y", "p", "e", "spc", "s", "u", "b", "t", "e", "s", "t", "dot", "d", "a", "t", "ret",
        "h", "e", "l", "l", "o", "e", "x", "e", "ret",
        "c", "d", "spc", "dot", "dot", "ret",
        "t", "y", "p", "e", "spc", "t", "e", "s", "t", "f", "i", "l", "e", "dot", "d", "a", "t", "ret",
        "n", "o", "p", "e", "ret",
        "e", "x", "i", "t", "ret",
    ]:
        sock.sendall(f"sendkey {key}\n".encode())
        time.sleep(0.15)
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
    for marker in [
        "LainDOS Shell",
        "A:\\>",
        "SHELL.COM",
        "HELLO.COM",
        "HELLOEXE.EXE",
        "Hello from TESTFILE.DAT! This is test data for LainDOS file I/O.",
        "PASS: HELLO.EXE",
        "EXECTEST.COM",
        "PASS: EXECTEST",
        "PASS: KEY",
        "PASS: TIME",
        "Largest free block: ",
        "A:\\SHDIR>",
        "Path not found",
        "A:\\MIDEMO>",
        "SUBTEST.DAT",
        "Hello from MIDEMO subdirectory!",
        "Bad command or file name",
        "Program exited, code=00",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    if output.count("PASS: HELLO.COM") >= 3:
        print("  PASS: found three HELLO.COM runs")
    else:
        print("  FAIL: expected three HELLO.COM runs")
        failed = True
    if output.count("Hello from TESTFILE.DAT! This is test data for LainDOS file I/O.") >= 2:
        print("  PASS: found root TYPE before and after CD ..")
    else:
        print("  FAIL: expected root TYPE before and after CD ..")
        failed = True
    if output.count("Path not found") == 1:
        print("  PASS: CD .. at root did not error")
    else:
        print("  FAIL: expected exactly one Path not found")
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
    print("\nShell test passed.")


if __name__ == "__main__":
    main()
