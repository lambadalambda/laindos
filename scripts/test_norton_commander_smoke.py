#!/usr/bin/env python3
import os
import shutil
import struct

from fatlib import FatImage, entry_attr, entry_cluster, entry_name, entry_size, iter_dir
import sys
import tempfile
import time

from testlib import (
    unique_monitor_socket, unique_vnc_arg,
    build_dir,
    check_markers,
    collect_output,
    framebuffer_active,
    monitor_quit,
    monitor_screendump,
    open_monitor,
    qemu_binary,
    qemu_vga,
    remove_if_exists,
    run_cmd,
    start_qemu,
    stop_qemu,
)


ARCHIVE = "vendor/003064_norton_commander.7z"
BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "norton_commander")
EXTRACT_DIR = os.path.join(WORKDIR, "archive")
FILES_DIR = os.path.join(WORKDIR, "files")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
IMG = os.path.join(WORKDIR, "norton_commander.img")
MONITOR = unique_monitor_socket("norton-commander-smoke")
SCREENSHOT = os.path.join(WORKDIR, "norton_commander.ppm")
TIMEOUT = int(os.environ.get("NC_SMOKE_WAIT", "12"))


def extract_fat12_root(image, output_dir):
    img = FatImage.from_file(image)
    extracted = []
    for _, entry in iter_dir(img.root_dir()):
        if entry_attr(entry) & 0x18:
            continue
        path = os.path.join(output_dir, entry_name(entry))
        with open(path, "wb") as f:
            f.write(img.read_chain(entry_cluster(entry), entry_size(entry)))
        extracted.append(path)
    return extracted


def build_image():
    if not os.path.exists(ARCHIVE):
        print(f"Missing {ARCHIVE}", file=sys.stderr)
        sys.exit(1)
    if shutil.which("bsdtar") is None:
        print("Missing bsdtar needed to extract Norton Commander archive", file=sys.stderr)
        sys.exit(1)
    shutil.rmtree(WORKDIR, ignore_errors=True)
    os.makedirs(EXTRACT_DIR, exist_ok=True)
    os.makedirs(FILES_DIR, exist_ok=True)
    run_cmd(["bsdtar", "-xf", ARCHIVE, "-C", EXTRACT_DIR])
    disk1 = os.path.join(EXTRACT_DIR, "003064_norton_commander", "disk01.img")
    files = extract_fat12_root(disk1, FILES_DIR)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="NC      EXE"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT, KERNEL, IMG, *files])


def run_qemu():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
    ])
    sock = None
    try:
        sock = open_monitor(MONITOR)
        time.sleep(TIMEOUT)
        monitor_screendump(sock, SCREENSHOT)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads)


def main():
    build_image()
    output = run_qemu()
    failed = not check_markers(
        output,
        required=("LainDOS booted", "EXE loaded", "The Norton Commander Version 5.5"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=", "Program exited, code="),
        dump_on_failure=False,
    )
    failed = not framebuffer_active(SCREENSHOT, "Norton Commander framebuffer", min_colors=2, min_nonblack=1000) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nNorton Commander smoke passed.")


if __name__ == "__main__":
    main()
