#!/usr/bin/env python3
import os
import shutil
import sys
import tempfile
import time

import test_norton_commander_copy as nccopy
import test_norton_commander_smoke as nc
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
    send_monitor_key,
    send_monitor_text,
    start_qemu,
    stop_qemu,
    wait_for_output,
)


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "norton_commander_rename_delete")
EXTRACT_DIR = os.path.join(WORKDIR, "archive")
FILES_DIR = os.path.join(WORKDIR, "files")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
HELLO = os.path.join(WORKDIR, "hello.com")
IMG = os.path.join(WORKDIR, "norton_commander_rename_delete.img")
SCREENSHOT_RENAME = os.path.join(WORKDIR, "norton_commander_rename.ppm")
SCREENSHOT_DELETE = os.path.join(WORKDIR, "norton_commander_delete.ppm")
TIMEOUT = int(os.environ.get("NC_RENAME_DELETE_WAIT", "18"))


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


def run_nc(keys, monitor_name, screenshot):
    monitor = unique_monitor_socket(monitor_name)
    remove_if_exists(monitor)
    remove_if_exists(screenshot)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{monitor},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
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


def run_rename():
    return run_nc([
        ("key", "f6", 1),
        ("key", "ctrl-y", 0.2),
        ("text", "HELLO3.COM", 0.1),
        ("key", "ret", 4),
    ], "norton-commander-rename", SCREENSHOT_RENAME)


def run_delete():
    # HELLO3.COM sorts first under NC's default name ordering after the rename.
    return run_nc([
        ("key", "f8", 1),
        ("key", "ret", 4),
    ], "norton-commander-delete", SCREENSHOT_DELETE)


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
    hello = nccopy.root_file_contents(IMG, "HELLO.COM")
    if hello is None:
        print("  FAIL: HELLO.COM not found before rename")
        sys.exit(1)
    if nccopy.root_file_contents(IMG, "HELLO3.COM") is not None:
        print("  FAIL: HELLO3.COM exists before rename")
        sys.exit(1)

    rename_output = run_rename()
    failed = not check_common_output(rename_output, "rename")
    renamed = nccopy.root_file_contents(IMG, "HELLO3.COM")
    if nccopy.root_file_contents(IMG, "HELLO.COM") is not None:
        print("  FAIL: HELLO.COM still exists after rename")
        failed = True
    elif renamed == hello:
        print("  PASS: HELLO3.COM matches original HELLO.COM")
    elif renamed is None:
        print("  FAIL: HELLO3.COM not found after rename")
        failed = True
    else:
        print("  FAIL: HELLO3.COM contents changed during rename")
        failed = True
    failed = not framebuffer_active(SCREENSHOT_RENAME, "Norton Commander rename framebuffer", min_colors=2, min_nonblack=1000) or failed
    if failed:
        print("\n--- rename QEMU serial output ---")
        print(rename_output)
        print("--- end ---")
        sys.exit(1)

    delete_output = run_delete()
    failed = not check_common_output(delete_output, "delete")
    if nccopy.root_file_contents(IMG, "HELLO3.COM") is None:
        print("  PASS: HELLO3.COM removed after delete")
    else:
        print("  FAIL: HELLO3.COM still exists after delete")
        failed = True
    failed = not framebuffer_active(SCREENSHOT_DELETE, "Norton Commander delete framebuffer", min_colors=2, min_nonblack=1000) or failed
    if failed:
        print("\n--- delete QEMU serial output ---")
        print(delete_output)
        print("--- end ---")
        sys.exit(1)
    print("\nNorton Commander rename/delete smoke passed.")


if __name__ == "__main__":
    main()
