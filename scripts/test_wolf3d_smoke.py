#!/usr/bin/env python3
import os
import sys
import tempfile
import time
from testlib import (
    build_dir,
    unique_monitor_socket, unique_vnc_arg,
    check_markers,
    collect_output,
    framebuffer_active,
    monitor_quit,
    monitor_screendump,
    open_monitor,
    qemu_vga,
    qemu_sb16_adlib_silent_args,
    remove_if_exists,
    run_cmd,
    start_qemu,
    stop_qemu,
)

IMG = os.path.join(build_dir(), "wolf3d.img")
MONITOR = unique_monitor_socket("wolf3d-smoke")
SCREENSHOT = os.path.join(build_dir(), "wolf3d_smoke_screen.ppm")
TIMEOUT = int(os.environ.get("WOLF3D_SMOKE_WAIT", "25"))


def run_qemu():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
        *qemu_sb16_adlib_silent_args(),
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
    if not os.path.exists("vendor/wolf3dsw.zip"):
        print("Missing vendor/wolf3dsw.zip", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_wolf3d.py"])
    output = run_qemu()
    failed = not check_markers(output, ["LainDOS booted", "EXE loaded"], dump_on_failure=False)
    failed = not framebuffer_active(SCREENSHOT, "Wolf3D framebuffer") or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nWolf3D smoke passed.")


if __name__ == "__main__":
    main()
