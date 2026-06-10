#!/usr/bin/env python3
import os
import socket
import subprocess
import sys
import time
from testlib import run_cmd, build_dir, finish_qemu, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "autoexec.img")
KERNEL = os.path.join(BUILDDIR, "autoexec_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "autoexec.sock")


def build_image(with_autoexec):
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", os.path.join(BUILDDIR, "shell.com")])
    run_cmd(["nasm", "-f", "bin", "tests/programs/hello.asm", "-o", os.path.join(BUILDDIR, "hello.com")])
    files = [
        os.path.join(BUILDDIR, "shell.com"),
        os.path.join(BUILDDIR, "hello.com"),
    ]
    if with_autoexec:
        with open(os.path.join(BUILDDIR, "autoexec.bat"), "wb") as f:
            f.write(
                b"echo autoexec start\r\n"
                b"rem ignored comment\r\n"
                b"\r\n"
                b"md startup\r\n"
                b"cd startup\r\n"
                b"echo in startup dir\r\n"
                b"cd ..\r\n"
                b"hello\r\n"
                b"nope\r\n"
                b"echo autoexec done\r\n"
            )
        files.append(os.path.join(BUILDDIR, "autoexec.bat"))
    run_cmd([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        *files,
    ])


def send_monitor_key(sock, key):
    sock.sendall(f"sendkey {key}\n".encode())
    time.sleep(0.15)


def send_text(sock, text):
    keymap = {" ": "spc", "\\": "backslash", ".": "dot"}
    for ch in text:
        send_monitor_key(sock, keymap.get(ch, ch.lower()))


def send_keys(output_chunks, ready_marker):
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
    if not wait_for_output(output_chunks, ready_marker, timeout=15, stop_markers=()):
        raise TimeoutError(f"timed out waiting for {ready_marker!r}")
    send_text(sock, "exit")
    send_monitor_key(sock, "ret")
    sock.close()


def run_qemu(ready_marker):
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
        send_keys(stdout_chunks, ready_marker)
    except Exception:
        proc.kill()
        proc.wait()
        for thread in threads:
            thread.join(timeout=1)
        raise
    output, _ = finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=8, stop_markers=("HALT", "Program exited, code=00"))
    return output


def check_present_output(output):
    failed = False
    for marker in [
        "autoexec start",
        "in startup dir",
        "PASS: HELLO.COM",
        "Bad command or file name",
        "autoexec done",
        "A:\\>",
        "Program exited, code=00",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    bad = output.find("Bad command or file name")
    done = output.find("autoexec done")
    if bad != -1 and done > bad:
        print("  PASS: batch continued after bad command")
    else:
        print("  FAIL: batch did not continue after bad command")
        failed = True
    return failed


def check_absent_output(output):
    failed = False
    for marker in ["LainDOS Shell", "A:\\>", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found no-AUTOEXEC '{marker}'")
        else:
            print(f"  FAIL: missing no-AUTOEXEC '{marker}'")
            failed = True
    for marker in ["autoexec start", "autoexec done", "File not found"]:
        if marker in output:
            print(f"  FAIL: unexpected no-AUTOEXEC '{marker}'")
            failed = True
    return failed


def check_unexpected(output):
    failed = False
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    return failed


def main():
    build_image(True)
    output = run_qemu("autoexec done")
    failed = check_present_output(output)
    failed = check_unexpected(output) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)

    build_image(False)
    output = run_qemu("A:\\>")
    failed = check_absent_output(output)
    failed = check_unexpected(output) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nAUTOEXEC test passed.")


if __name__ == "__main__":
    main()
