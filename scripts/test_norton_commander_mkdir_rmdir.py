#!/usr/bin/env python3
import os
import shutil
import struct
import sys
import tempfile
import time

import test_norton_commander_copy as nccopy
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


DIR_NAME = "AAADIR"
BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "norton_commander_mkdir_rmdir")
EXTRACT_DIR = os.path.join(WORKDIR, "archive")
FILES_DIR = os.path.join(WORKDIR, "files")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
IMG = os.path.join(WORKDIR, "norton_commander_mkdir_rmdir.img")
SCREENSHOT_MKDIR = os.path.join(WORKDIR, "norton_commander_mkdir.ppm")
SCREENSHOT_RMDIR = os.path.join(WORKDIR, "norton_commander_rmdir.ppm")
TIMEOUT = int(os.environ.get("NC_MKDIR_RMDIR_WAIT", "18"))


def raw_83(name):
    if name == ".":
        return b".       " + b"   "
    if name == "..":
        return b"..      " + b"   "
    parts = name.upper().split(".", 1)
    ext = parts[1] if len(parts) > 1 else ""
    return parts[0].ljust(8)[:8].encode("ascii") + ext.ljust(3)[:3].encode("ascii")


def image_layout(image):
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
    return data, bps, spc, fat_off, root_off, root_entries, data_off, bits


def root_entry(image, name):
    layout = image_layout(image)
    if layout is None:
        return None, None
    data, _, _, _, root_off, root_entries, _, _ = layout
    target = raw_83(name)
    for off in range(root_off, root_off + root_entries * 32, 32):
        entry = data[off:off + 32]
        if entry[0] == 0:
            break
        attr = entry[11]
        # Keep directories visible; this smoke searches for AAADIR.
        if entry[0] == 0xE5 or attr == 0x0F or attr & 0x08:
            continue
        if entry[:11] == target:
            return entry, layout
    return None, layout


def root_dir_valid(image, name):
    entry, layout = root_entry(image, name)
    if entry is None or layout is None or not (entry[11] & 0x10):
        return False
    data, bps, spc, fat_off, _, _, data_off, bits = layout
    cluster = struct.unpack_from("<H", entry, 26)[0]
    dir_data = nccopy.read_chain(data, bps, spc, fat_off, data_off, bits, cluster, bps * spc)
    if len(dir_data) < 64:
        return False
    dot = dir_data[0:32]
    dotdot = dir_data[32:64]
    dot_cluster = struct.unpack_from("<H", dot, 26)[0]
    dotdot_cluster = struct.unpack_from("<H", dotdot, 26)[0]
    return (
        dot[:11] == raw_83(".") and (dot[11] & 0x10) and dot_cluster == cluster and
        dotdot[:11] == raw_83("..") and (dotdot[11] & 0x10) and dotdot_cluster == 0
    )


def root_name_exists(image, name):
    entry, _ = root_entry(image, name)
    return entry is not None


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
    if not files:
        print("FAIL: no files extracted from Norton Commander archive", file=sys.stderr)
        sys.exit(1)
    first_panel_name = min(os.path.basename(path).upper() for path in files)
    if DIR_NAME >= first_panel_name:
        print(f"Expected {DIR_NAME} to sort before NC files, found {first_panel_name}", file=sys.stderr)
        sys.exit(1)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="NC      EXE"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT, KERNEL, IMG, *files])


def run_nc(keys, monitor_name, screenshot):
    monitor = os.path.join(tempfile.gettempdir(), monitor_name)
    remove_if_exists(monitor)
    remove_if_exists(screenshot)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{monitor},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", "127.0.0.1:44",
    ])
    sock = None
    try:
        sock = open_monitor(monitor)
        if not wait_for_output(stdout_chunks, "The Norton Commander Version 5.5", timeout=TIMEOUT, stop_markers=("EXC ", "INT 21h AH=")):
            raise TimeoutError("Norton Commander did not reach startup marker")
        time.sleep(2)
        for action, value, delay in keys:
            if action == "text":
                send_monitor_text(sock, value, delay=delay)
            else:
                send_monitor_key(sock, value, delay=delay)
        monitor_screendump(sock, screenshot, delay=0.5)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads)


def run_mkdir():
    return run_nc([
        ("key", "f7", 1),
        ("key", "ctrl-y", 0.2),
        ("text", DIR_NAME, 0.1),
        ("key", "ret", 4),
    ], "laindos-norton-commander-mkdir.sock", SCREENSHOT_MKDIR)


def run_rmdir():
    # NC directory deletion uses an options dialog, then a second delete prompt.
    return run_nc([
        ("key", "f8", 1),
        ("key", "tab", 0.2),
        ("key", "tab", 0.2),
        ("key", "tab", 0.2),
        ("key", "ret", 1),
        ("key", "ret", 4),
    ], "laindos-norton-commander-rmdir.sock", SCREENSHOT_RMDIR)


def check_common_output(output, label):
    return check_markers(
        output,
        required=("LainDOS booted", "EXE loaded", "The Norton Commander Version 5.5"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=", "Program exited, code="),
        output_label=f"{label} QEMU serial output",
        dump_on_failure=False,
    )


def main():
    build_image()
    if root_name_exists(IMG, DIR_NAME):
        print(f"  FAIL: {DIR_NAME} exists before mkdir")
        sys.exit(1)

    mkdir_output = run_mkdir()
    failed = not check_common_output(mkdir_output, "mkdir")
    if root_dir_valid(IMG, DIR_NAME):
        print(f"  PASS: {DIR_NAME} directory has valid dot entries")
    else:
        print(f"  FAIL: {DIR_NAME} directory metadata is invalid")
        failed = True
    failed = not framebuffer_active(SCREENSHOT_MKDIR, "Norton Commander mkdir framebuffer", min_colors=2, min_nonblack=1000) or failed
    if failed:
        print("\n--- mkdir QEMU serial output ---")
        print(mkdir_output)
        print("--- end ---")
        sys.exit(1)

    rmdir_output = run_rmdir()
    failed = not check_common_output(rmdir_output, "rmdir")
    if root_name_exists(IMG, DIR_NAME):
        print(f"  FAIL: {DIR_NAME} still exists after rmdir")
        failed = True
    else:
        print(f"  PASS: {DIR_NAME} removed after rmdir")
    failed = not framebuffer_active(SCREENSHOT_RMDIR, "Norton Commander rmdir framebuffer", min_colors=2, min_nonblack=1000) or failed
    if failed:
        print("\n--- rmdir QEMU serial output ---")
        print(rmdir_output)
        print("--- end ---")
        sys.exit(1)
    print("\nNorton Commander mkdir/rmdir smoke passed.")


if __name__ == "__main__":
    main()
