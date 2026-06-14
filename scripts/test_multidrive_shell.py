#!/usr/bin/env python3
import os
import re
import socket
import sys
import time

from testlib import build_dir, check_markers, finish_qemu, run_cmd, start_qemu, wait_for_output


QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
FLOPPY_IMG = os.path.join(BUILDDIR, "multidrive_shell_floppy.img")
HD_IMG = os.path.join(BUILDDIR, "multidrive_shell_hd.img")
KERNEL = os.path.join(BUILDDIR, "multidrive_shell_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
BOOT16 = os.path.join(BUILDDIR, "boot16.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
HELLO = os.path.join(BUILDDIR, "hello.com")
HDONLY = os.path.join(BUILDDIR, "hdonly.txt")
MONITOR = os.path.join(BUILDDIR, "multidrive_shell.sock")
PROMPT_RE = re.compile(rb"[AC]:\\[^>\r\n]*>")
KEYMAP = {" ": "spc", "\\": "backslash", ".": "dot", ":": "shift-semicolon"}


def build_images():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(HDONLY, "wb") as f:
        f.write(b"Hello from C drive!\r\n")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT16])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["python3", "scripts/build_shell_com.py", SHELL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/hello.asm", "-o", HELLO])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, FLOPPY_IMG, SHELL])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT16, KERNEL, HD_IMG, HELLO, HDONLY])


def send_key(sock, key):
    sock.sendall(f"sendkey {key} 10\n".encode())
    time.sleep(0.02)


def send_text(sock, text):
    for ch in text:
        if ch.isalnum():
            key = ch.lower()
        elif ch in KEYMAP:
            key = KEYMAP[ch]
        else:
            raise ValueError(f"unmapped key {ch!r}")
        send_key(sock, key)


def prompt_count(chunks):
    return len(PROMPT_RE.findall(b"".join(chunks)))


def wait_for_prompt_count(chunks, count, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = b"".join(chunks)
        if len(PROMPT_RE.findall(output)) >= count:
            return
        for marker in (b"FAIL:", b"EXC ", b"INT 21h AH=", b"HALT"):
            if marker in output:
                raise RuntimeError(f"saw {marker!r} while waiting for prompt")
        time.sleep(0.02)
    raise TimeoutError("timed out waiting for prompt")


def send_command(sock, chunks, command, timeout=10):
    target = prompt_count(chunks) + 1
    send_text(sock, command)
    send_key(sock, "ret")
    wait_for_prompt_count(chunks, target, timeout=timeout)


def drive_shell(sock, chunks):
    deadline = time.time() + 8
    while True:
        try:
            sock.connect(MONITOR)
            break
        except OSError:
            if time.time() > deadline:
                raise
            time.sleep(0.1)
    sock.recv(4096)
    send_command(sock, chunks, "c:")
    send_command(sock, chunks, "dir")
    send_command(sock, chunks, "type hdonly.txt")
    send_command(sock, chunks, "hello")
    send_text(sock, "exit")
    send_key(sock, "ret")


def run_qemu():
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        QEMU,
        "-drive", f"file={FLOPPY_IMG},format=raw,if=floppy",
        "-drive", f"file={HD_IMG},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-nographic",
    ])
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        if not wait_for_output(stdout_chunks, "A:\\>", timeout=10, stop_markers=()):
            raise TimeoutError("timed out waiting for A:\\>")
        drive_shell(sock, stdout_chunks)
    except Exception:
        proc.kill()
        proc.wait()
        for thread in threads:
            thread.join(timeout=1)
        raise
    finally:
        sock.close()
    output, _ = finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=8, stop_markers=("HALT", "Program exited, code=00"))
    return output


def main():
    build_images()
    output = run_qemu()
    if not check_markers(output, required=("A:\\>", "C:\\>", "HDONLY   TXT", "Hello from C drive!", "PASS: HELLO.COM", "Program exited, code=00"),
                         forbidden=("FAIL:", "EXC ", "INT 21h AH=", "Bad command or file name")):
        sys.exit(1)
    print("\nMulti-drive shell test passed.")


if __name__ == "__main__":
    main()
