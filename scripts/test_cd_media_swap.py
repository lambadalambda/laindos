#!/usr/bin/env python3
"""CD-ROM media changes invalidate cached PVD, directory, and file state."""
import os
import sys

from testlib import (
    build_dir,
    check_markers,
    collect_output,
    finish_qemu,
    open_monitor,
    qemu_binary,
    remove_if_exists,
    run_cmd,
    send_monitor_command,
    send_monitor_key,
    start_qemu,
    stop_qemu,
    unique_monitor_socket,
    unique_vnc_arg,
    wait_for_output,
)


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_media_swap")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdswap.com")
OLD_PAYLOAD = os.path.join(WORKDIR, "old.txt")
NEW_PAYLOAD = os.path.join(WORKDIR, "newfile.txt")
IMG = os.path.join(WORKDIR, "cd_media_swap.img")
OLD_ISO = os.path.join(WORKDIR, "old.iso")
NEW_ISO = os.path.join(WORKDIR, "new.iso")
MONITOR = unique_monitor_socket("cd-media-swap")
TIMEOUT = 20
SECTOR = 2048
PVD_LBA = 16


def patch_volume_id(path, label):
    with open(path, "r+b") as f:
        f.seek(PVD_LBA * SECTOR + 40)
        f.write(label.encode("ascii").ljust(32, b" "))


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(OLD_PAYLOAD, "wb") as f:
        f.write(b"OLD!\r\n")
    with open(NEW_PAYLOAD, "wb") as f:
        f.write(b"NEW!\r\n")
    run_cmd(["python3", "scripts/mkiso.py", OLD_ISO, f"OLD.TXT={OLD_PAYLOAD}"])
    run_cmd(["python3", "scripts/mkiso.py", NEW_ISO, f"NEWFILE.TXT={NEW_PAYLOAD}"])
    patch_volume_id(OLD_ISO, "OLDCD")
    patch_volume_id(NEW_ISO, "NEWCD")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDSWAP  COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdswap.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_artifacts()
    remove_if_exists(MONITOR)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-drive", f"file={OLD_ISO},format=raw,if=ide,media=cdrom,readonly=on",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vnc", unique_vnc_arg(),
    ])
    sock = None
    ok = True
    timed_out = False
    try:
        sock = open_monitor(MONITOR)
        if not wait_for_output(stdout_chunks, "READY: CDSWAP", timeout=TIMEOUT):
            ok = False
        else:
            send_monitor_command(sock, "eject -f ide0-cd0", delay=0.5)
            send_monitor_command(sock, f"change ide0-cd0 {os.path.abspath(NEW_ISO)} raw", delay=1.0)
            send_monitor_key(sock, "spc")
        output, timed_out = finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=TIMEOUT)
    finally:
        if sock is not None:
            try:
                sock.close()
            except OSError:
                pass
        stop_qemu(proc)
    if 'output' not in locals():
        output = collect_output(stdout_chunks, stderr_chunks, threads)
    if timed_out:
        print(f"FAIL: QEMU ran for {TIMEOUT}s without reaching a stop marker (hang?)")
        ok = False
    ok = check_markers(
        output,
        required=("READY: CDSWAP", "PASS: CDSWAP", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD media-swap QEMU serial output",
        dump_on_failure=False,
    ) and ok
    if not ok:
        print("\n--- CD media-swap QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nCD media-swap test passed.")


if __name__ == "__main__":
    main()
