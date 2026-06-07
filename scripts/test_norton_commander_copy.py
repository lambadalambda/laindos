#!/usr/bin/env python3
import os
import shutil
import struct
import sys
import tempfile
import time

import test_norton_commander_smoke as nc
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
    send_monitor_key,
    send_monitor_text,
    start_qemu,
    stop_qemu,
    wait_for_output,
)


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "norton_commander_copy")
EXTRACT_DIR = os.path.join(WORKDIR, "archive")
FILES_DIR = os.path.join(WORKDIR, "files")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
HELLO = os.path.join(WORKDIR, "hello.com")
IMG = os.path.join(WORKDIR, "norton_commander_copy.img")
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-norton-commander-copy.sock")
SCREENSHOT = os.path.join(WORKDIR, "norton_commander_copy.ppm")
TIMEOUT = int(os.environ.get("NC_COPY_WAIT", "18"))


def fat_next(data, fat_off, cluster, bits):
    if bits == 16:
        return struct.unpack_from("<H", data, fat_off + cluster * 2)[0]
    off = fat_off + cluster + cluster // 2
    value = data[off] | (data[off + 1] << 8)
    return value >> 4 if cluster & 1 else value & 0x0FFF


def read_chain(data, bps, spc, fat_off, data_off, bits, cluster, size):
    chunks = []
    seen = set()
    eoc = 0xFFF8 if bits == 16 else 0xFF8
    while 2 <= cluster < eoc and cluster not in seen:
        seen.add(cluster)
        off = data_off + (cluster - 2) * bps * spc
        chunks.append(data[off:off + bps * spc])
        cluster = fat_next(data, fat_off, cluster, bits)
    return b"".join(chunks)[:size]


def root_file_contents(image, filename):
    target = filename.upper().split(".", 1)
    target_raw = target[0].ljust(8)[:8].encode("ascii") + (target[1] if len(target) > 1 else "").ljust(3)[:3].encode("ascii")
    with open(image, "rb") as f:
        data = f.read()
    bps = struct.unpack_from("<H", data, 11)[0]
    spc = data[13]
    if bps == 0 or spc == 0:
        return None
    reserved = struct.unpack_from("<H", data, 14)[0]
    fat_count = data[16]
    root_entries = struct.unpack_from("<H", data, 17)[0]
    total = struct.unpack_from("<H", data, 19)[0] or struct.unpack_from("<I", data, 32)[0]
    sectors_per_fat = struct.unpack_from("<H", data, 22)[0]
    root_sectors = (root_entries * 32 + bps - 1) // bps
    fat_off = reserved * bps
    root_off = (reserved + fat_count * sectors_per_fat) * bps
    data_off = (reserved + fat_count * sectors_per_fat + root_sectors) * bps
    data_sectors = total - (reserved + fat_count * sectors_per_fat + root_sectors)
    bits = 12 if data_sectors // spc < 4085 else 16
    for off in range(root_off, root_off + root_entries * 32, 32):
        entry = data[off:off + 32]
        if entry[0] == 0:
            break
        attr = entry[11]
        if entry[0] == 0xE5 or attr == 0x0F or attr & 0x18:
            continue
        if entry[:11] != target_raw:
            continue
        cluster = struct.unpack_from("<H", entry, 26)[0]
        size = struct.unpack_from("<I", entry, 28)[0]
        return read_chain(data, bps, spc, fat_off, data_off, bits, cluster, size)
    return None


def build_image():
    if not os.path.exists(nc.ARCHIVE):
        print(f"Missing {nc.ARCHIVE}", file=sys.stderr)
        sys.exit(1)
    if shutil.which("bsdtar") is None:
        print("Missing bsdtar needed to extract Norton Commander archive", file=sys.stderr)
        sys.exit(1)
    shutil.rmtree(WORKDIR, ignore_errors=True)
    os.makedirs(EXTRACT_DIR, exist_ok=True)
    os.makedirs(FILES_DIR, exist_ok=True)
    run_cmd(["bsdtar", "-xf", nc.ARCHIVE, "-C", EXTRACT_DIR])
    disk1 = os.path.join(EXTRACT_DIR, "003064_norton_commander", "disk01.img")
    files = nc.extract_fat12_root(disk1, FILES_DIR)
    first_panel_name = min([os.path.basename(path).upper() for path in files] + ["HELLO.COM"])
    if first_panel_name != "HELLO.COM":
        print(f"Expected HELLO.COM to sort first, found {first_panel_name}", file=sys.stderr)
        sys.exit(1)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="NC      EXE"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/hello.asm", "-o", HELLO])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT, KERNEL, IMG, *files, HELLO])


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
        "-vnc", "127.0.0.1:42",
    ])
    sock = None
    try:
        sock = open_monitor(MONITOR)
        if not wait_for_output(stdout_chunks, "The Norton Commander Version 5.5", timeout=TIMEOUT, stop_markers=("EXC ", "INT 21h AH=")):
            raise TimeoutError("Norton Commander did not reach startup marker")
        time.sleep(2)
        send_monitor_key(sock, "f5", delay=1)
        send_monitor_key(sock, "ctrl-y", delay=0.2)
        send_monitor_text(sock, "HELLO2.COM", delay=0.1)
        send_monitor_key(sock, "ret", delay=4)
        monitor_screendump(sock, SCREENSHOT, delay=0.5)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads)


def main():
    build_image()
    if root_file_contents(IMG, "HELLO2.COM") is not None:
        print("  FAIL: HELLO2.COM exists before copy")
        sys.exit(1)
    output = run_qemu()
    failed = not check_markers(
        output,
        required=("LainDOS booted", "EXE loaded", "The Norton Commander Version 5.5"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=", "Program exited, code="),
        dump_on_failure=False,
    )
    hello = root_file_contents(IMG, "HELLO.COM")
    copied = root_file_contents(IMG, "HELLO2.COM")
    if hello is None:
        print("  FAIL: HELLO.COM not found in image")
        failed = True
    elif copied is None:
        print("  FAIL: HELLO2.COM not found after copy")
        failed = True
    elif copied == hello:
        print("  PASS: HELLO2.COM matches HELLO.COM")
    else:
        print("  FAIL: HELLO2.COM was not copied correctly")
        failed = True
    failed = not framebuffer_active(SCREENSHOT, "Norton Commander copy framebuffer", min_colors=2, min_nonblack=1000) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nNorton Commander copy smoke passed.")


if __name__ == "__main__":
    main()
