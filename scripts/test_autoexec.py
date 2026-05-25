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
IMG = os.path.join(BUILDDIR, "autoexec.img")
KERNEL = os.path.join(BUILDDIR, "autoexec_kernel.bin")
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-autoexec.sock")


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_image(with_autoexec):
    os.makedirs(BUILDDIR, exist_ok=True)
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/shell.asm", "-o", os.path.join(BUILDDIR, "shell.com")])
    run(["nasm", "-f", "bin", "src/hello.asm", "-o", os.path.join(BUILDDIR, "hello.com")])
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
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        *files,
    ])


def wait_for_output(chunks, marker, timeout=10):
    needle = marker.encode()
    deadline = time.time() + timeout
    while time.time() < deadline:
        if needle in b"".join(chunks):
            return
        time.sleep(0.05)
    raise TimeoutError(f"timed out waiting for {marker!r}")


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
    wait_for_output(output_chunks, ready_marker)
    send_text(sock, "exit")
    send_monitor_key(sock, "ret")
    sock.close()


def read_stream(stream, chunks):
    while True:
        data = os.read(stream.fileno(), 1024)
        if not data:
            return
        chunks.append(data)


def run_qemu(ready_marker):
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
    try:
        send_keys(stdout_chunks, ready_marker)
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


def check_present_output(output):
    failed = False
    for marker in [
        "AUTOEXEC START",
        "IN STARTUP DIR",
        "PASS: HELLO.COM",
        "Bad command or file name",
        "AUTOEXEC DONE",
        "A:\\>",
        "Program exited, code=00",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    bad = output.find("Bad command or file name")
    done = output.find("AUTOEXEC DONE")
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
    for marker in ["AUTOEXEC START", "AUTOEXEC DONE", "File not found"]:
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
    output = run_qemu("AUTOEXEC DONE")
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
