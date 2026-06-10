#!/usr/bin/env python3
import os
import sys
import tempfile
import time
from testlib import (
    unique_monitor_socket, unique_vnc_arg,
    DEFAULT_FAIL_MARKERS,
    check_markers,
    collect_output,
    framebuffer_active,
    monitor_quit,
    monitor_screendump,
    open_monitor,
    qemu_vga,
    qemu_sb16_silent_args,
    remove_if_exists,
    run_cmd,
    send_monitor_key,
    send_monitor_text,
    start_qemu,
    stop_qemu,
    wait_for_output,
)

IMG = "build/shell_monkey.img"
MONITOR = unique_monitor_socket("shell-monkey")
SCREENSHOT = "build/shell_monkey_screen.ppm"
TIMEOUT = int(os.environ.get("MONKEY_DEMO_SMOKE_WAIT", "18"))


def run_qemu():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
        *qemu_sb16_silent_args(),
    ])
    sock = None
    prompt_ok = False
    try:
        sock = open_monitor(MONITOR, timeout=10)
        prompt_ok = wait_for_output(stdout_chunks, "A:\\>", timeout=20, stop_markers=DEFAULT_FAIL_MARKERS)
        if prompt_ok:
            send_monitor_text(sock, "midemo", delay=0.08)
            send_monitor_key(sock, "ret", delay=5.0)
            send_monitor_key(sock, "esc", delay=0.2)
            time.sleep(TIMEOUT)
        monitor_screendump(sock, SCREENSHOT)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), prompt_ok


def main():
    if not os.path.exists("vendor/midemo.exe"):
        print("Missing vendor/midemo.exe", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_shell_monkey.py"])
    output, prompt_ok = run_qemu()
    if not prompt_ok:
        print("  FAIL: timed out waiting for A:\\>")
    forbidden = DEFAULT_FAIL_MARKERS + ("File not found", "Runtime error")
    required = ["LainDOS booted", "LainDOS Shell", "A:\\>midemo"]
    failed = not prompt_ok
    failed = not check_markers(output, required, forbidden, dump_on_failure=False) or failed
    failed = not framebuffer_active(SCREENSHOT, "Monkey demo framebuffer", min_colors=4, min_nonblack=1000) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nShell Monkey demo smoke passed.")


if __name__ == "__main__":
    main()
