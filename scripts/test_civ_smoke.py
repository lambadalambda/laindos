#!/usr/bin/env python3
"""Vendor-gated Civilization smoke: LOADFIX placement and game startup.

CIV.EXE is EXEPACK-compressed, and the unpacker corrupts itself below
segment 1000h -- the placement a faithful lean DOS-in-HMA layout
produces, just like real MS-DOS 5 (whose answer was LOADFIX.COM).
This smoke launches through LOADFIX and verifies the game reaches the
startup menus and an animating VGA intro.

The smoke deliberately stops at the animated intro: Civilization's
INT 08 hook interacts badly with QEMU's PIT (the BIOS tick drops to a
third rate and a presentation card later stalls or dies with R6003),
and the same behavior reproduces under FreeDOS on this QEMU, so it is
an emulator-timing issue rather than a LainDOS one.
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

ARCHIVE = "vendor/sid-meiers-civilization-au.zip"
IMG = "build/civ_hd.img"
MONITOR = unique_monitor_socket("civ-smoke")
TEXT = "build/civ_smoke_text.bin"
TICK = "build/civ_smoke_tick.bin"
SCREENSHOT = "build/civ_smoke_screen.ppm"

INTRO_DEADLINE = 120
INTRO_MIN_COLORS = 10
INTRO_MIN_NONBLACK = 5000


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
        f"timed out waiting for text {needle!r}; last screen:\n"
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


def wait_for_intro(sock):
    deadline = time.time() + INTRO_DEADLINE
    stats = None
    while time.time() < deadline:
        monitor_screendump(sock, SCREENSHOT, delay=0.5)
        stats = ppm_stats(SCREENSHOT)
        if stats is not None:
            colors, nonblack = stats
            if colors >= INTRO_MIN_COLORS and nonblack >= INTRO_MIN_NONBLACK:
                print(f"  PASS: intro framebuffer active ({colors} colors, {nonblack} nonblack pixels)")
                return
        screen = monitor_text_screen(sock, TEXT)
        if "R6003" in screen:
            raise SmokeFailure("game crashed with R6003 before the intro")
        time.sleep(5)
    raise SmokeFailure(f"no active intro framebuffer within {INTRO_DEADLINE}s; last stats: {stats}")


def check_tick_advances(sock):
    before = bios_tick(sock)
    time.sleep(3)
    after = bios_tick(sock)
    if after <= before:
        raise SmokeFailure(f"BIOS tick frozen during the intro: {before} -> {after}")
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
        shell_command(sock, "cd civ")
        time.sleep(1)
        shell_command(sock, "loadfix civ")
        wait_text(sock, "Select graphics mode:", 30)
        print("  PASS: LOADFIX CIV reaches the graphics menu")
        send_monitor_key(sock, "1")
        wait_text(sock, "Select sound mode:", 15)
        send_monitor_key(sock, "1")
        time.sleep(2)
        send_monitor_key(sock, "1")
        wait_for_intro(sock)
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
    run_cmd(["python3", "scripts/build_civ_hd.py"])
    failure, output = run_smoke()
    failed = failure is not None
    if failure is not None:
        print(f"  FAIL: {failure}")
    failed = not check_markers(
        output,
        required=("LainDOS booted",),
        forbidden=DEFAULT_FAIL_MARKERS,
        dump_on_failure=False,
    ) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("\nCivilization smoke failed.")
        sys.exit(1)
    print("Civilization smoke passed.")


if __name__ == "__main__":
    main()
