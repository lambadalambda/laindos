#!/usr/bin/env python3
"""Vendor-gated Micro Machines 2 smoke: floppy install and DOS/4GW launch.

Boots a blank LainDOS hard disk with installer disk 1 in A:, drives the
real Codemasters installer through language selection, destination, and
three floppy swaps (exercising the HD-boot floppy drive and the
change-line media remount), then launches the installed game and verifies
it reaches its interactive copy-protection screen under DOS/4GW with the
BIOS tick advancing. Going further needs the manual's symbol card, so the
smoke stops at that screen.
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

ARCHIVE = "vendor/003513_micro_machines_2.7z"
IMG = "build/mm2_hd.img"
MONITOR = unique_monitor_socket("mm2-smoke")
TEXT = "build/mm2_smoke_text.bin"
TICK = "build/mm2_smoke_tick.bin"
SCREENSHOT = "build/mm2_smoke_screen.ppm"
KEYMAP = {":": "shift-semicolon"}

GAME_DEADLINE = 150
GAME_MIN_NONBLACK = 200000


class SmokeFailure(Exception):
    pass


def disk_image(n):
    return os.path.abspath(f"build/mm2_disk{n}.img")


def wait_text(sock, needle, timeout, step=1.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if needle in screen:
            return screen
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
    send_monitor_text(sock, command, delay=0.06, keymap=KEYMAP)
    send_monitor_key(sock, "ret")


def drive_installer(sock):
    shell_command(sock, "a:")
    time.sleep(1)
    shell_command(sock, "install")
    wait_text(sock, "Select Language", 30)
    send_monitor_key(sock, "spc", delay=0.5)
    send_monitor_key(sock, "ret", delay=1.0)
    wait_text(sock, "Thank you for purchasing", 15)
    send_monitor_key(sock, "ret", delay=1.0)
    wait_text(sock, "destination path", 15)
    send_monitor_key(sock, "ret", delay=1.0)
    deadline = time.time() + 240
    swapped = set()
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if "Installation Complete" in screen:
            return
        for n in (2, 3, 4):
            if n not in swapped and f"insert Disk {n}" in screen:
                send_monitor_command(sock, f"change floppy0 {disk_image(n)} raw", delay=1.5)
                send_monitor_key(sock, "ret")
                swapped.add(n)
                print(f"  PASS: swapped to disk {n} on prompt")
        time.sleep(2)
    raise SmokeFailure(
        "installer did not complete; last screen:\n" + monitor_text_screen(sock, TEXT)
    )


def skip_sound_setup(sock):
    send_monitor_key(sock, "ret", delay=2.0)
    deadline = time.time() + 30
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if "Sound SetUp" in screen:
            send_monitor_key(sock, "esc", delay=1.0)
        if screen.rstrip().endswith(">"):
            return
        time.sleep(1)
    raise SmokeFailure(
        "no shell prompt after install; last screen:\n" + monitor_text_screen(sock, TEXT)
    )


def wait_for_game_screen(sock):
    deadline = time.time() + GAME_DEADLINE
    stats = None
    while time.time() < deadline:
        monitor_screendump(sock, SCREENSHOT, delay=0.5)
        stats = ppm_stats(SCREENSHOT)
        if stats is not None and stats[1] >= GAME_MIN_NONBLACK:
            print(f"  PASS: game screen active ({stats[0]} colors, {stats[1]} nonblack pixels)")
            return
        time.sleep(5)
    raise SmokeFailure(f"no game screen within {GAME_DEADLINE}s; last stats: {stats}")


def check_tick_advances(sock):
    before = bios_tick(sock)
    time.sleep(3)
    after = bios_tick(sock)
    if after <= before:
        raise SmokeFailure(f"BIOS tick frozen at the game screen: {before} -> {after}")
    print(f"  PASS: BIOS tick advancing ({before} -> {after})")


def run_smoke():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={disk_image(1)},format=raw,if=floppy",
        "-drive", f"file={IMG},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vnc", unique_vnc_arg(),
        "-snapshot",
        "-device", "sb16,audiodev=snd0",
        "-device", "adlib,audiodev=snd0",
        "-audiodev", "none,id=snd0",
    ])
    sock = None
    failure = None
    try:
        sock = open_monitor(MONITOR)
        wait_text(sock, "C:\\>", 30)
        drive_installer(sock)
        print("  PASS: installer completed")
        skip_sound_setup(sock)
        shell_command(sock, "c:")
        time.sleep(1)
        shell_command(sock, "cd \\mm2")
        time.sleep(1)
        shell_command(sock, "mm2")
        wait_for_game_screen(sock)
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
    run_cmd(["python3", "scripts/build_mm2_hd.py"])
    failure, output = run_smoke()
    failed = failure is not None
    if failure is not None:
        print(f"  FAIL: {failure}")
    failed = not check_markers(
        output,
        required=("LainDOS booted", "DOS/4GW Protected Mode Run-time"),
        forbidden=DEFAULT_FAIL_MARKERS,
        dump_on_failure=False,
    ) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("\nMicro Machines 2 smoke failed.")
        sys.exit(1)
    print("Micro Machines 2 smoke passed.")


if __name__ == "__main__":
    main()
