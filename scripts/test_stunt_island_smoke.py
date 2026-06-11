#!/usr/bin/env python3
"""Vendor-gated Stunt Island smoke: install from source media, launch STUNT,
and verify the game reaches its interactive startup prompt.

Rebuilds build/stunt_hd.img from vendor/002514_stunt_island.7z, boots it
with QEMU -snapshot, drives the Disney installer through its default
choreography (Welcome, Setup, Destination Path, copy, Installation
Complete), launches STUNT from C:\\STUNTISL, and waits for the
competition-prompt screen class: a high-color stable framebuffer with the
BIOS tick still advancing. The frozen-tick black screen was the historical
failure mode of the IF-on-IRET-return bug, so the tick check is the part
that guards the faithful interrupt semantics.
"""
import os
import struct
import sys
import time

from testlib import (
    DEFAULT_FAIL_MARKERS,
    check_markers,
    collect_output,
    monitor_quit,
    monitor_screendump,
    monitor_text_screen,
    open_monitor,
    ppm_stats,
    qemu_binary,
    remove_if_exists,
    run_cmd,
    send_monitor_command,
    send_monitor_key,
    send_monitor_text,
    start_qemu,
    stop_qemu,
    unique_monitor_socket,
    unique_vnc_arg,
)

ARCHIVE = "vendor/002514_stunt_island.7z"
IMG = "build/stunt_hd.img"
MONITOR = unique_monitor_socket("stunt-smoke")
TEXT = "build/stunt_smoke_text.bin"
TICK = "build/stunt_smoke_tick.bin"
SCREENSHOT = "build/stunt_smoke_screen.ppm"

PROMPT_DEADLINE = 240
PROMPT_MIN_COLORS = 150
PROMPT_MIN_NONBLACK = 100000


class SmokeFailure(Exception):
    pass


def wait_text(sock, needle, timeout, step=1.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if needle in screen:
            return
        time.sleep(step)
    raise SmokeFailure(
        f"timed out waiting for installer text {needle!r}; last screen:\n"
        + monitor_text_screen(sock, TEXT)
    )


def bios_tick(sock):
    remove_if_exists(TICK)
    send_monitor_command(sock, f"pmemsave 0x46c 4 {TICK}", delay=0.3)
    with open(TICK, "rb") as f:
        return struct.unpack("<I", f.read(4))[0]


def shell_command(sock, command):
    send_monitor_text(sock, command, delay=0.05)
    send_monitor_key(sock, "ret")


def drive_installer(sock):
    shell_command(sock, "install")
    wait_text(sock, "Press ENTER to continue", 30)
    send_monitor_key(sock, "ret")
    wait_text(sock, "Setup", 15)
    send_monitor_key(sock, "ret")
    wait_text(sock, "Destination Path", 15)
    send_monitor_key(sock, "ret")
    wait_text(sock, "Installation Complete", 180)
    send_monitor_key(sock, "ret")
    time.sleep(3)


def wait_for_prompt_screen(sock):
    deadline = time.time() + PROMPT_DEADLINE
    while time.time() < deadline:
        monitor_screendump(sock, SCREENSHOT, delay=0.5)
        stats = ppm_stats(SCREENSHOT)
        if stats is not None:
            colors, nonblack = stats
            if colors >= PROMPT_MIN_COLORS and nonblack >= PROMPT_MIN_NONBLACK:
                print(f"  PASS: prompt-class screen ({colors} colors, {nonblack} nonblack pixels)")
                return
        time.sleep(5)
    raise SmokeFailure(f"no prompt-class screen within {PROMPT_DEADLINE}s; last stats: {stats}")


def check_tick_advances(sock):
    before = bios_tick(sock)
    time.sleep(3)
    after = bios_tick(sock)
    if after <= before:
        raise SmokeFailure(f"BIOS tick frozen at the prompt screen: {before} -> {after}")
    print(f"  PASS: BIOS tick advancing ({before} -> {after})")


def run_smoke():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={IMG},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vnc", unique_vnc_arg(),
        "-snapshot",
    ])
    sock = None
    failure = None
    try:
        sock = open_monitor(MONITOR)
        wait_text(sock, "C:\\>", 30)
        drive_installer(sock)
        shell_command(sock, "cd \\stuntisl")
        time.sleep(1)
        shell_command(sock, "stunt")
        wait_for_prompt_screen(sock)
        check_tick_advances(sock)
        monitor_quit(sock, proc)
    except SmokeFailure as exc:
        failure = str(exc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return failure, collect_output(stdout_chunks, stderr_chunks, threads)


def main():
    if not os.path.exists(ARCHIVE):
        print(f"Missing {ARCHIVE}", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_stunt_hd.py"])
    failure, output = run_smoke()
    failed = failure is not None
    if failure is not None:
        print(f"  FAIL: {failure}")
    failed = not check_markers(
        output,
        required=("LainDOS booted", "C:\\>install"),
        forbidden=DEFAULT_FAIL_MARKERS,
        dump_on_failure=False,
    ) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("\nStunt Island smoke failed.")
        sys.exit(1)
    print("Stunt Island smoke passed.")


if __name__ == "__main__":
    main()
