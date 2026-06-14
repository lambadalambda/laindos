#!/usr/bin/env python3
"""A: is the real BIOS floppy when booting from hard disk, and a media
change is picked up on the next access.

Real DOS booted from C: still exposes the floppy as A:, and re-reads
the volume when the disk is swapped — through the change-line error
(INT 13h error 06h) when a physical read is in flight, and through a
MEDIA CHECK (with the 2-second rule) before cached FAT/root data is
trusted when no read would otherwise happen. Era floppy installers —
Micro Machines 2's and Wing Commander's among them — depend on these.
"""
import os
import sys
import time

from testlib import (
    build_dir,
    check_markers,
    collect_output,
    monitor_quit,
    open_monitor,
    qemu_binary,
    remove_if_exists,
    run_cmd,
    send_monitor_command,
    send_monitor_key,
    send_monitor_text,
    start_qemu,
    stop_qemu,
    unique_monitor_socket,
    unique_vnc_arg,
)

BUILDDIR = build_dir()
HD_IMG = os.path.join(BUILDDIR, "hdfloppy_hd.img")
DISK1 = os.path.join(BUILDDIR, "hdfloppy_disk1.img")
DISK2 = os.path.join(BUILDDIR, "hdfloppy_disk2.img")
KERNEL = os.path.join(BUILDDIR, "hdfloppy_kernel.bin")
MONITOR = unique_monitor_socket("hdfloppy")
KEYMAP = {":": "shift-semicolon"}


def build_images():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    boot16 = os.path.join(BUILDDIR, "boot16.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    one = os.path.join(BUILDDIR, "disk1.txt")
    two = os.path.join(BUILDDIR, "disk2.txt")
    with open(one, "wb") as f:
        f.write(b"ALPHA-MARKER\r\n")
    with open(two, "wb") as f:
        f.write(b"BRAVO-MARKER\r\n")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", boot16])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/build_shell_com.py", shell])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd32m", boot16, KERNEL, HD_IMG, shell])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, DISK1, one])
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, DISK2, two])


def wait_serial(chunks, needle, after, timeout, label):
    """Wait for needle in the serial stream past offset `after`; return the
    end offset of the match, or None."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        text = b"".join(chunks).decode("utf-8", "replace")
        pos = text.find(needle, after)
        if pos >= 0:
            print(f"  PASS: {label}")
            return pos + len(needle)
        time.sleep(0.5)
    print(f"  FAIL: {label}: {needle!r} not on serial after offset {after}")
    return None


def shell_command(sock, command):
    send_monitor_text(sock, command, delay=0.06, keymap=KEYMAP)
    send_monitor_key(sock, "ret")


def main():
    build_images()
    remove_if_exists(MONITOR)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={DISK1},format=raw,if=floppy",
        "-drive", f"file={HD_IMG},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vnc", unique_vnc_arg(),
    ])
    sock = None
    ok = True
    pos = 0
    try:
        sock = open_monitor(MONITOR)
        got = wait_serial(stdout_chunks, "C:\\>", pos, 20, "boot prompt")
        ok = got is not None and ok
        pos = got or pos
        shell_command(sock, "type a:\\disk1.txt")
        got = wait_serial(stdout_chunks, "ALPHA-MARKER", pos, 10, "floppy file from HD boot")
        ok = got is not None and ok
        pos = got or pos
        send_monitor_command(sock, f"change floppy0 {os.path.abspath(DISK2)} raw", delay=1.0)
        shell_command(sock, "type a:\\disk2.txt")
        got = wait_serial(stdout_chunks, "BRAVO-MARKER", pos, 10, "file after media change")
        ok = got is not None and ok
        pos = got or pos
        shell_command(sock, "type a:\\disk1.txt")
        got = wait_serial(stdout_chunks, "File not found", pos, 10, "stale file rejected after swap")
        ok = got is not None and ok
        pos = got or pos
        # Swap while A: is the *current* drive: every lookup is served from
        # the cached FAT/root, so detection must come from a media check,
        # not from a physical read's change-line error. The media check
        # honors DOS's 2-second rule, so wait past it like a human swap.
        shell_command(sock, "a:")
        shell_command(sock, "type disk2.txt")
        got = wait_serial(stdout_chunks, "BRAVO-MARKER", pos, 10, "current-drive read before swap")
        ok = got is not None and ok
        pos = got or pos
        send_monitor_command(sock, f"change floppy0 {os.path.abspath(DISK1)} raw", delay=3.0)
        shell_command(sock, "type disk1.txt")
        got = wait_serial(stdout_chunks, "ALPHA-MARKER", pos, 10, "media change seen on current drive")
        ok = got is not None and ok
        pos = got or pos
        shell_command(sock, "type disk2.txt")
        got = wait_serial(stdout_chunks, "File not found", pos, 10, "stale file rejected on current drive")
        ok = got is not None and ok
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    output = collect_output(stdout_chunks, stderr_chunks, threads)
    ok = check_markers(
        output,
        required=("ALPHA-MARKER", "BRAVO-MARKER"),
        forbidden=("FAIL:", "EXC "),
        output_label="hdfloppy QEMU serial output",
        dump_on_failure=False,
    ) and ok
    if not ok:
        print("\n--- QEMU serial output ---")
        print(output)
        sys.exit(1)
    print("HD-boot floppy drive test passed.")


if __name__ == "__main__":
    main()
