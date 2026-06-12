#!/usr/bin/env python3
"""Vendor-gated Wing Commander smoke: floppy install, quiz, bar scene.

Boots a blank LainDOS hard disk with installer disk 1 in A:, drives the
real Origin installer through its menus and two floppy swaps (exercising
the HD-boot floppy drive and the media check), launches the game, answers
the Claw Marks copy-protection question (read out of guest RAM and looked
up in the documented answer table), clicks Start Vega Campaign, enters a
pilot name, and verifies the game reaches the animated bar scene with the
BIOS tick advancing.
"""
import os
import re
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

VENDOR_DIR = "vendor/wing-commander_202104"
IMG = "build/wc_hd.img"
MONITOR = unique_monitor_socket("wc-smoke")
TEXT = "build/wc_smoke_text.bin"
TICK = "build/wc_smoke_tick.bin"
RAM = "build/wc_smoke_ram.bin"
SCREENSHOT = "build/wc_smoke_screen.ppm"
KEYMAP = {":": "shift-semicolon"}

BAR_DEADLINE = 150
BAR_MIN_COLORS = 100
BAR_MIN_NONBLACK = 180000

# The Claw Marks quiz table (Origin's own press answer sheet, cross-checked
# against the CIC list). Keyword sets identify the randomly drawn question.
ANSWERS = [
    (("DART", "ESK"), "11000"),
    (("MASS DRIVER",), "3000"),
    (("PILUM",), "9500"),
    (("DART", "VELOCITY"), "900"),
    (("LASER",), "4800"),
    (("FRALTHI",), "28"),
    (("TIGER'S CLAW", "LAUNCHED"), "2644"),
    (("RALARI",), "18000"),
    (("MANIAC",), "23"),
    (("ASTEROID",), "250"),
    (("TREES",), "7225"),
    (("CONSERVATION",), "12500"),
    (("NEUTRON",), "2618"),
    (("GODDARD",), "75000"),
    (("PUBLICATION",), "16548"),
    (("PRIESTESSES",), "9500"),
    (("WARSHIPS",), "3715"),
    (("SYSTEMS", "SIVAR"), "25768"),
    (("KOHL",), "2621"),
]


class SmokeFailure(Exception):
    pass


def disk_image(n):
    return os.path.abspath(f"build/wc_disk{n}.img")


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


def fb_stats(sock):
    monitor_screendump(sock, SCREENSHOT, delay=0.4)
    return ppm_stats(SCREENSHOT)


def drive_installer(sock):
    shell_command(sock, "a:")
    time.sleep(1)
    shell_command(sock, "install")
    wait_text(sock, "Disk Drive Installation Menu", 30)
    send_monitor_text(sock, "c", delay=0.3)
    send_monitor_key(sock, "ret", delay=1.5)
    send_monitor_key(sock, "ret", delay=1.5)
    wait_text(sock, "compressed", 15)
    # Save Space: skip the lengthy VGA art expansion pass; the game runs
    # from the compressed files just as well
    send_monitor_key(sock, "down", delay=0.5)
    send_monitor_key(sock, "ret", delay=1.0)
    wait_text(sock, "Graphics Installation Menu", 15)
    send_monitor_key(sock, "ret", delay=1.0)
    wait_text(sock, "Sound System Installation Menu", 15)
    send_monitor_key(sock, "ret", delay=1.0)
    wait_text(sock, "configuration correct", 15)
    send_monitor_text(sock, "y")
    deadline = time.time() + 300
    swapped = set()
    ems_note_seen = False
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if "Finished copying" in screen:
            send_monitor_key(sock, "ret")
            print("  PASS: installer copied all three disks")
            break
        if not ems_note_seen and "Expanded Memory Specification" in screen:
            # Save Space prints an EMS recommendation first; the game runs
            # fine without EMS
            send_monitor_key(sock, "ret")
            ems_note_seen = True
        for n in (2, 3):
            if n not in swapped and f"Disk {n}" in screen and "insert" in screen:
                # wait out the kernel's 2-second media-check window, swap,
                # settle, then answer the "press any key" prompt
                time.sleep(3)
                send_monitor_command(sock, f"change floppy0 {disk_image(n)} raw", delay=3.0)
                send_monitor_key(sock, "ret")
                swapped.add(n)
                print(f"  PASS: swapped to disk {n} on prompt")
        time.sleep(2)
    else:
        raise SmokeFailure(
            "installer did not finish copying; last screen:\n"
            + monitor_text_screen(sock, TEXT)
        )
    # the installer repeats the EMS note on its way out
    deadline = time.time() + 120
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if screen.rstrip().endswith(">"):
            return
        if "Press any key to continue" in screen:
            send_monitor_key(sock, "ret")
        time.sleep(3)
    raise SmokeFailure(
        "no shell prompt after install; last screen:\n"
        + monitor_text_screen(sock, TEXT)
    )


def read_question(sock):
    remove_if_exists(RAM)
    send_monitor_command(sock, f"pmemsave 0 655360 {RAM}", delay=2.0)
    with open(RAM, "rb") as f:
        data = f.read()
    best = None
    for m in re.finditer(rb"[ -~]{25,200}", data):
        s = m.group().decode("ascii")
        if s.rstrip().endswith("?") and answer_for(s):
            best = s
    return best


def answer_for(question):
    upper = question.upper()
    for keys, answer in ANSWERS:
        if all(k in upper for k in keys):
            return answer
    return None


def pass_quiz(sock):
    deadline = time.time() + 120
    question = None
    while time.time() < deadline:
        question = read_question(sock)
        if question:
            break
        send_monitor_key(sock, "spc", delay=0.2)
        time.sleep(2)
    if not question:
        raise SmokeFailure("no known quiz question found in guest RAM")
    answer = answer_for(question)
    print(f"  PASS: quiz question identified: {question.strip()!r} -> {answer}")
    send_monitor_text(sock, answer, delay=0.15)
    send_monitor_key(sock, "ret")
    time.sleep(4)


def read_ppm():
    with open(SCREENSHOT, "rb") as f:
        assert f.readline().strip() == b"P6"
        line = f.readline()
        while line.startswith(b"#"):
            line = f.readline()
        w, h = map(int, line.split())
        f.readline()
        return w, h, f.read(w * h * 3)


def grab_pixels(sock):
    fb_stats(sock)
    return read_ppm()


def diff_cursor(before, after):
    """Median position of pixels that changed between two dumps: the
    cursor, since the menu background is static. Robust to the cursor
    sprite changing shape and color (it does)."""
    (w, h, a), (_, _, b) = before, after
    pts = []
    for y in range(0, h, 2):
        row = y * w * 3
        for x in range(0, w, 2):
            i = row + x * 3
            if a[i:i + 3] != b[i:i + 3]:
                pts.append((x, y))
    if not pts or len(pts) > 800:
        return None  # nothing moved, or the whole screen changed
    xs = sorted(p[0] for p in pts)
    ys = sorted(p[1] for p in pts)
    return xs[len(xs) // 2], ys[len(ys) // 2]


def click_vega_campaign(sock):
    """ENTER on this menu means abort; it wants a mouse click."""
    target = (320, 110)  # Start Vega Campaign button center, 640x400 dump coords
    before = grab_pixels(sock)
    send_monitor_command(sock, "mouse_move 25 25", delay=0.5)
    for _ in range(30):
        after = grab_pixels(sock)
        cur = diff_cursor(before, after)
        before = after
        if cur is None:
            send_monitor_command(sock, "mouse_move 25 25", delay=0.5)
            continue
        if 130 <= cur[0] <= 510 and 80 <= cur[1] <= 140:
            send_monitor_command(sock, "mouse_button 1", delay=0.25)
            send_monitor_command(sock, "mouse_button 0", delay=0.5)
            print("  PASS: clicked Start Vega Campaign")
            return
        dx, dy = target[0] - cur[0], target[1] - cur[1]
        # half-gain damping: cursor motion is rate-scaled by the game
        send_monitor_command(sock, f"mouse_move {max(-80, min(80, dx//2))} {max(-80, min(80, dy//2))}", delay=0.5)
    raise SmokeFailure("could not steer the mouse cursor to the campaign button")


def enter_pilot(sock):
    time.sleep(18)  # arcade intro plays out
    send_monitor_text(sock, "soykaf", delay=0.2)
    send_monitor_key(sock, "ret", delay=1.0)
    time.sleep(2)
    send_monitor_text(sock, "laindos", delay=0.2)
    send_monitor_key(sock, "ret", delay=1.0)
    time.sleep(8)
    send_monitor_key(sock, "esc", delay=0.5)  # climb out of the simulator


def wait_for_bar(sock):
    deadline = time.time() + BAR_DEADLINE
    stats = None
    while time.time() < deadline:
        stats = fb_stats(sock)
        if stats is not None and stats[0] >= BAR_MIN_COLORS and stats[1] >= BAR_MIN_NONBLACK:
            print(f"  PASS: bar scene active ({stats[0]} colors, {stats[1]} nonblack pixels)")
            return
        time.sleep(5)
    raise SmokeFailure(f"no bar scene within {BAR_DEADLINE}s; last stats: {stats}")


def check_tick_advances(sock):
    before = bios_tick(sock)
    time.sleep(3)
    after = bios_tick(sock)
    if after <= before:
        raise SmokeFailure(f"BIOS tick frozen at the bar scene: {before} -> {after}")
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
    ])
    sock = None
    failure = None
    try:
        sock = open_monitor(MONITOR)
        wait_text(sock, "C:\\>", 30)
        drive_installer(sock)
        print("  PASS: installer completed")
        shell_command(sock, "c:")
        time.sleep(1)
        shell_command(sock, "cd \\wing")
        time.sleep(1)
        shell_command(sock, "wc")
        time.sleep(8)
        pass_quiz(sock)
        click_vega_campaign(sock)
        enter_pilot(sock)
        wait_for_bar(sock)
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
    if not os.path.exists(os.path.join(VENDOR_DIR, "disk1.ima")):
        print(f"Missing {VENDOR_DIR}/disk1..3.ima", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_wc_hd.py"])
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
        print("\nWing Commander smoke failed.")
        sys.exit(1)
    print("Wing Commander smoke passed.")


if __name__ == "__main__":
    main()
