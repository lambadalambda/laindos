#!/usr/bin/env python3
"""Vendor-gated Settlers II Gold smoke: CD install and launch to the menu.

Boots a blank LainDOS C: with the Gold Edition data-track ISO as D:, runs
the real Blue Byte installer (DOS/4GW graphics UI: ENTER activates the
focused menu button, SPACE activates dialog buttons), reboots out of the post-install Setup
menu (which QEMU's stalled input dispatch leaves no way to exit — see
drive_installer), then launches the installed game and
verifies it reaches its 640x480 VESA main menu with the BIOS tick
advancing. Under QEMU the game's timer-driven input pump
does not run (an emulator interaction of the Civilization PIT class), so
the smoke stops at the menu; under 86Box the game is fully playable.
"""
import os
import struct
import sys
import time

from testlib import (
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

CUE = "vendor/die-siedler-2-gold/CD01.cue"
C_IMG = "build/settlers2_c.img"
ISO = "build/settlers2_cd.iso"
MONITOR = unique_monitor_socket("s2-smoke")
TEXT = "build/s2_smoke_text.bin"
TICK = "build/s2_smoke_tick.bin"
SCREENSHOT = "build/s2_smoke_screen.ppm"
KEYMAP = {":": "shift-semicolon"}

MENU_DEADLINE = 120
MENU_MIN_COLORS = 100
MENU_MIN_NONBLACK = 250000

# the SIEDLER2.EXE CauseWay VMM launcher errors out under LainDOS and the
# game falls back to a direct DOS/4GW start; that error is expected
FAIL_MARKERS = ("FAIL:", "EXC ", "INT 21h AH=", "DOS/4GW error",
                "Packed file is corrupt")


class SmokeFailure(Exception):
    pass


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


def fb_stats(sock):
    monitor_screendump(sock, SCREENSHOT, delay=0.4)
    return ppm_stats(SCREENSHOT)


def shell_command(sock, command):
    send_monitor_text(sock, command, delay=0.06, keymap=KEYMAP)
    send_monitor_key(sock, "ret")


def drive_installer(sock):
    shell_command(sock, "d:")
    time.sleep(1)
    shell_command(sock, "cd s2")
    time.sleep(1)
    shell_command(sock, "setup")
    deadline = time.time() + 60
    while time.time() < deadline:
        stats = fb_stats(sock)
        if stats is not None and stats[0] >= 200:
            break
        time.sleep(2)
    else:
        raise SmokeFailure(f"installer menu never appeared; stats: {fb_stats(sock)}")
    send_monitor_key(sock, "ret", delay=0.5)   # Siedler II Gold installieren
    time.sleep(3)
    send_monitor_key(sock, "spc", delay=0.5)   # drive dialog: C: button
    time.sleep(3)
    send_monitor_key(sock, "ret", delay=0.5)   # accept C:\BLUEBYTE\SIEDLER2
    print("  PASS: installer driven (drive C:, default path)")
    # the static "wird nun installiert" screen shows while copying (about a
    # minute); the success dialog replaces it
    time.sleep(8)
    copying = fb_stats(sock)
    deadline = time.time() + 240
    while time.time() < deadline:
        stats = fb_stats(sock)
        if stats is not None and stats != copying:
            break
        time.sleep(5)
    else:
        raise SmokeFailure(f"installer never finished copying; stats: {copying}")
    print("  PASS: install copy finished")
    time.sleep(2)
    send_monitor_key(sock, "spc", delay=0.5)   # O.K. on "erfolgreich installiert"
    time.sleep(3)
    # Under QEMU the post-install Setup menu cannot be left by input: no key
    # moves its button focus and mouse clicks never fire (cursor motion and
    # ENTER/SPACE do get through) — the same emulator interaction that
    # stalls the game's input pump; under 86Box the keyboard works. Exit the
    # period way instead: reboot after installing. The -snapshot overlay
    # carries the installed C: across the reset.
    send_monitor_command(sock, "system_reset", delay=1.0)
    wait_text(sock, "C:\\>", 60)
    print("  PASS: install survives a reboot, back at the shell")


def launch_game(sock):
    shell_command(sock, "c:")
    time.sleep(1)
    shell_command(sock, "cd \\bluebyte\\siedler2")
    time.sleep(1)
    shell_command(sock, "start")
    time.sleep(20)
    send_monitor_key(sock, "ret", delay=0.5)   # past the splash
    deadline = time.time() + MENU_DEADLINE
    stats = None
    while time.time() < deadline:
        stats = fb_stats(sock)
        if stats is not None and stats[0] >= MENU_MIN_COLORS and stats[1] >= MENU_MIN_NONBLACK:
            print(f"  PASS: 640x480 menu screen active ({stats[0]} colors, {stats[1]} nonblack pixels)")
            return
        send_monitor_key(sock, "ret", delay=0.3)
        time.sleep(5)
    raise SmokeFailure(f"no menu screen within {MENU_DEADLINE}s; last stats: {stats}")


def check_tick_advances(sock):
    before = bios_tick(sock)
    time.sleep(3)
    after = bios_tick(sock)
    if after <= before:
        raise SmokeFailure(f"BIOS tick frozen at the menu: {before} -> {after}")
    print(f"  PASS: BIOS tick advancing ({before} -> {after})")


def run_smoke():
    remove_if_exists(MONITOR)
    remove_if_exists(SCREENSHOT)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={C_IMG},format=raw,if=ide,index=0,media=disk",
        "-drive", f"file={ISO},format=raw,if=ide,index=1,media=cdrom,readonly=on",
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
        launch_game(sock)
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
    if not os.path.exists(CUE):
        print(f"Missing {CUE}", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_settlers2.py"])
    failure, output = run_smoke()
    failed = failure is not None
    if failure is not None:
        print(f"  FAIL: {failure}")
    failed = not check_markers(
        output,
        required=("LainDOS booted", "DOS/4GW Protected Mode Run-time"),
        forbidden=FAIL_MARKERS,
        dump_on_failure=False,
    ) or failed
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("\nSettlers II smoke failed.")
        sys.exit(1)
    print("Settlers II smoke passed.")


if __name__ == "__main__":
    main()
