#!/usr/bin/env python3
import os
import sys
import tempfile
import time
from testlib import (
    check_markers,
    collect_output,
    framebuffer_active,
    monitor_quit,
    monitor_screendump,
    open_monitor,
    remove_if_exists,
    run_cmd,
    start_qemu,
    stop_qemu,
)

IMG = "build/monkey_full.img"
TIMEOUT = 25
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-monkey-full.sock")
SCREENSHOT = "build/monkey_full_screen.ppm"


def run_qemu():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vnc", "127.0.0.1:29",
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
    if not os.path.exists("vendor/monkey_full.zip"):
        print("Missing vendor/monkey_full.zip", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_monkey_full.py"])
    output = run_qemu()
    failed = not check_markers(output, ["LainDOS booted", "EXE loaded"], dump_on_failure=False)
    failed = not framebuffer_active(SCREENSHOT) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFull Monkey smoke passed.")


if __name__ == "__main__":
    main()
