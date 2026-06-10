#!/usr/bin/env python3
import os
import shutil
import sys
import tempfile
import time
import zipfile
from testlib import (
    unique_monitor_socket, unique_vnc_arg,
    check_markers,
    collect_output,
    framebuffer_active,
    monitor_quit,
    monitor_screendump,
    open_monitor,
    qemu_vga,
    remove_if_exists,
    run_cmd,
    send_monitor_key,
    start_qemu,
    stop_qemu,
)

ARCHIVE = "vendor/SHRTLINE.zip"
BUILDDIR = "build"
WORKDIR = os.path.join(BUILDDIR, "shortline_smoke_files")
BOOT = os.path.join(BUILDDIR, "shortline_smoke_boot.bin")
KERNEL = os.path.join(BUILDDIR, "shortline_smoke_kernel.bin")
IMG = os.path.join(BUILDDIR, "shortline_smoke.img")
MONITOR = unique_monitor_socket("shortline-smoke")
SCREENSHOT = os.path.join(BUILDDIR, "shortline_smoke_screen.ppm")
TIMEOUT = int(os.environ.get("SHORTLINE_SMOKE_WAIT", "25"))


def build_image():
    if os.path.exists(WORKDIR):
        shutil.rmtree(WORKDIR)
    os.makedirs(WORKDIR, exist_ok=True)
    with zipfile.ZipFile(ARCHIVE) as archive:
        archive.extractall(WORKDIR)
    game_dir = os.path.join(WORKDIR, "SHRTLINE")
    files = [os.path.join(game_dir, name) for name in os.listdir(game_dir)]
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="SL      EXE"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT, KERNEL, IMG, *files])


def run_qemu():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
        "-icount", "shift=6,align=off,sleep=off",
    ])
    sock = None
    try:
        sock = open_monitor(MONITOR)
        time.sleep(TIMEOUT)
        for i in range(40):
            send_monitor_key(sock, "ret" if i % 2 == 0 else "spc", delay=0.25)
        time.sleep(20)
        monitor_screendump(sock, SCREENSHOT)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads)


def main():
    if not os.path.exists(ARCHIVE):
        print(f"Missing {ARCHIVE}", file=sys.stderr)
        sys.exit(1)
    build_image()
    output = run_qemu()
    failed = not check_markers(
        output,
        required=("LainDOS booted", "EXE loaded"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=", "Divide by 0"),
        dump_on_failure=False,
    )
    failed = not framebuffer_active(SCREENSHOT, "Shortline framebuffer", min_colors=8, min_nonblack=200000) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nShortline smoke passed.")


if __name__ == "__main__":
    main()
