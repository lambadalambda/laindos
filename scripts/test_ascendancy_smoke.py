#!/usr/bin/env python3
import os
import sys
import tempfile
import time
from testlib import (
    DEFAULT_FAIL_MARKERS,
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
    send_monitor_text,
    start_qemu,
    stop_qemu,
    wait_for_output,
)

IMG = "build/games_hd_all.img"
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-ascendancy-smoke.sock")
SCREENSHOT = "build/ascendancy_smoke_screen.ppm"
TIMEOUT = int(os.environ.get("ASCENDANCY_SMOKE_WAIT", "55"))


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
        "-vnc", "127.0.0.1:31",
        "-device", "sb16",
    ])
    sock = None
    try:
        sock = open_monitor(MONITOR, timeout=10)
        prompt_ok = wait_for_output(stdout_chunks, "C:\\>", timeout=25, stop_markers=DEFAULT_FAIL_MARKERS)
        if prompt_ok:
            for command in ["cd ascend", "ascend"]:
                send_monitor_text(sock, command, delay=0.08)
                send_monitor_key(sock, "ret", delay=0.5)
            time.sleep(TIMEOUT)
        monitor_screendump(sock, SCREENSHOT)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), prompt_ok


def main():
    if not os.path.exists("vendor/Ascendancy_1995.zip"):
        print("Missing vendor/Ascendancy_1995.zip", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_games_hd_all.py"])
    output, prompt_ok = run_qemu()
    if not prompt_ok:
        print("  FAIL: timed out waiting for C:\\>")
    forbidden = DEFAULT_FAIL_MARKERS + ("DOS/4GW fatal error", "Please place the Ascendancy CD")
    required = ["LainDOS booted", "LainDOS Shell", "C:\\ASCEND>ascend", "DOS/4GW", "Ascendancy"]
    failed = not prompt_ok
    failed = not check_markers(output, required, forbidden, dump_on_failure=False) or failed
    failed = not framebuffer_active(SCREENSHOT, "Ascendancy framebuffer") or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nAscendancy smoke passed.")


if __name__ == "__main__":
    main()
