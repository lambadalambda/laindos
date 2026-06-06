#!/usr/bin/env python3
import os
import shutil
import struct
import sys
import tempfile
import time

from testlib import (
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
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-norton-commander-smoke.sock")
SCREENSHOT = os.path.join(WORKDIR, "norton_commander.ppm")
TIMEOUT = int(os.environ.get("NC_SMOKE_WAIT", "12"))


def fat12_next(data, fat_off, cluster):
    off = fat_off + cluster + (cluster // 2)
    value = data[off] | (data[off + 1] << 8)
    if cluster & 1:
        return value >> 4
    return value & 0x0FFF


def extract_fat12_root(image, output_dir):
    with open(image, "rb") as f:
        data = f.read()
    bytes_per_sector = struct.unpack_from("<H", data, 11)[0]
    sectors_per_cluster = data[13]
    reserved = struct.unpack_from("<H", data, 14)[0]
    fat_count = data[16]
    root_entries = struct.unpack_from("<H", data, 17)[0]
    sectors_per_fat = struct.unpack_from("<H", data, 22)[0]
    fat_off = reserved * bytes_per_sector
    root_off = (reserved + fat_count * sectors_per_fat) * bytes_per_sector
    root_size = root_entries * 32
    data_off = root_off + root_size
    extracted = []

    for off in range(root_off, root_off + root_size, 32):
        entry = data[off:off + 32]
        if entry[0] == 0:
            break
        if entry[0] == 0xE5 or entry[11] & 0x18:
            continue
        name = entry[:8].decode("ascii", errors="replace").rstrip()
        ext = entry[8:11].decode("ascii", errors="replace").rstrip()
        filename = name + (f".{ext}" if ext else "")
        cluster = struct.unpack_from("<H", entry, 26)[0]
        size = struct.unpack_from("<I", entry, 28)[0]
        contents = bytearray()
        seen = set()
        while 2 <= cluster < 0xFF8 and cluster not in seen:
            seen.add(cluster)
            cluster_off = data_off + (cluster - 2) * sectors_per_cluster * bytes_per_sector
            contents.extend(data[cluster_off:cluster_off + sectors_per_cluster * bytes_per_sector])
            cluster = fat12_next(data, fat_off, cluster)
        path = os.path.join(output_dir, filename)
        with open(path, "wb") as f:
            f.write(bytes(contents[:size]))
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
        "-vnc", "127.0.0.1:33",
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
