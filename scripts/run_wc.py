#!/usr/bin/env python3
"""Boot an installed Wing Commander image in a visible QEMU window.

On first run (or with --reinstall) this stages the vendor floppies, then
drives the real Origin installer headlessly — drive C:, "Save Space",
the chosen sound option, both disk swaps — into a persistent
build/wc_installed.img. After that it boots the image with the normal
QEMU display, types CD WING + WC, and prints the Claw Marks
copy-protection answers so the quiz can be passed by hand.
"""
import argparse
import os
import shutil
import subprocess
import sys
import threading
import time

from testlib import (
    monitor_quit,
    monitor_text_screen,
    open_monitor,
    qemu_binary,
    qemu_vga,
    remove_if_exists,
    send_monitor_command,
    send_monitor_key,
    send_monitor_text,
    start_qemu,
    stop_qemu,
    unique_monitor_socket,
    unique_vnc_arg,
    wait_for_output,
)

STAGED_IMAGE = "build/wc_hd.img"
INSTALLED_IMAGE = "build/wc_installed.img"
MONITOR = os.path.join("build", "run_wc.sock")
TEXT = "build/run_wc_text.bin"
KEYMAP = {":": "shift-semicolon"}

SOUND_CHOICES = {"none": 0, "speaker": 1, "adlib": 2, "sb": 3, "mt32": 4}

QUIZ_ANSWERS = """\
Claw Marks copy-protection answers (Origin's press sheet):
  ESK rating of the Dart DF missile ......... 11000
  Max range of the mass driver cannon ....... 3000
  ESK rating of the Pilum FF missile ........ 9500
  Velocity of the Dart DF missile ........... 900
  Max range of a laser cannon ............... 4800
  Cm of front armor on the Fralthi .......... 28
  Year the Tiger's Claw was launched ........ 2644
  Weight of the Ralari ...................... 18000
  Maniac's age .............................. 23
  Safest speed in asteroid fields ........... 250
  Varieties of Terran trees transplanted .... 7225
  Kiloliters of Special Goddard exports ..... 75000
  Square km of Conservation Forest .......... 12500
  Year the neutron gun was invented ......... 2618
  Claw Marks publication number ............. 16548
  Priestesses in the Sivar Cult ............. 9500
  Warships at the Sivar-Eshrad .............. 3715
  Systems used to find the Sivar-Eshrad ..... 25768
  Year Dr Kohl observed the Sivar-Eshrad .... 2621
The campaign select wants a MOUSE CLICK; ENTER quits the game."""


class InstallFailure(Exception):
    pass


def disk_image(n):
    return os.path.abspath(f"build/wc_disk{n}.img")


def run_checked(command):
    subprocess.run(command, check=True)


def wait_text(sock, needle, timeout, step=1.0):
    deadline = time.time() + timeout
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if needle in screen:
            return screen
        time.sleep(step)
    raise InstallFailure(
        f"timed out waiting for text {needle!r}; last screen:\n"
        + monitor_text_screen(sock, TEXT)
    )


def shell_command(sock, command):
    send_monitor_text(sock, command, delay=0.06, keymap=KEYMAP)
    send_monitor_key(sock, "ret")


def drive_installer(sock, sound):
    shell_command(sock, "a:")
    time.sleep(1)
    shell_command(sock, "install")
    wait_text(sock, "Disk Drive Installation Menu", 30)
    send_monitor_text(sock, "c", delay=0.3)
    send_monitor_key(sock, "ret", delay=1.5)
    send_monitor_key(sock, "ret", delay=1.5)
    wait_text(sock, "compressed", 15)
    # Save Space: skip the lengthy VGA art expansion pass
    send_monitor_key(sock, "down", delay=0.5)
    send_monitor_key(sock, "ret", delay=1.0)
    wait_text(sock, "Graphics Installation Menu", 15)
    send_monitor_key(sock, "ret", delay=1.0)
    wait_text(sock, "Sound System Installation Menu", 15)
    for _ in range(SOUND_CHOICES[sound]):
        send_monitor_key(sock, "down", delay=0.4)
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
            print("installer: finished copying")
            break
        if not ems_note_seen and "Expanded Memory Specification" in screen:
            send_monitor_key(sock, "ret")
            ems_note_seen = True
        for n in (2, 3):
            if n not in swapped and f"Disk {n}" in screen and "insert" in screen:
                time.sleep(3)
                send_monitor_command(sock, f"change floppy0 {disk_image(n)} raw", delay=3.0)
                send_monitor_key(sock, "ret")
                swapped.add(n)
                print(f"installer: swapped to disk {n}")
        time.sleep(2)
    else:
        raise InstallFailure(
            "installer did not finish copying; last screen:\n"
            + monitor_text_screen(sock, TEXT)
        )
    deadline = time.time() + 120
    while time.time() < deadline:
        screen = monitor_text_screen(sock, TEXT)
        if screen.rstrip().endswith(">"):
            return
        if "Press any key to continue" in screen:
            send_monitor_key(sock, "ret")
        time.sleep(3)
    raise InstallFailure(
        "no shell prompt after install; last screen:\n"
        + monitor_text_screen(sock, TEXT)
    )


def install(sound):
    run_checked(["python3", "scripts/build_wc_hd.py"])
    shutil.copyfile(STAGED_IMAGE, INSTALLED_IMAGE)
    monitor = unique_monitor_socket("run-wc-install")
    remove_if_exists(monitor)
    print(f"Installing Wing Commander into {INSTALLED_IMAGE} (sound: {sound})...")
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={disk_image(1)},format=raw,if=floppy",
        "-drive", f"file={INSTALLED_IMAGE},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{monitor},server,nowait",
        "-vnc", unique_vnc_arg(),
    ])
    sock = None
    try:
        sock = open_monitor(monitor)
        wait_text(sock, "C:\\>", 30)
        drive_installer(sock, sound)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    print("Install complete.")


def read_stream_live(stream, chunks, dst):
    try:
        while True:
            data = os.read(stream.fileno(), 4096)
            if not data:
                return
            chunks.append(data)
            dst.write(data)
            dst.flush()
    except OSError:
        return


def parse_args():
    parser = argparse.ArgumentParser(description="Boot installed Wing Commander and launch WC.")
    parser.add_argument("--reinstall", action="store_true",
                        help="redo the floppy install even if the installed image exists")
    parser.add_argument("--sound", choices=sorted(SOUND_CHOICES), default="adlib",
                        help="sound option the installer selects (default: adlib)")
    parser.add_argument("--no-launch", action="store_true",
                        help="boot to the shell without typing CD WING + WC")
    parser.add_argument("--no-snapshot", action="store_true",
                        help="let the session write back to the installed image "
                             "(pilot saves persist)")
    parser.add_argument("--vnc", default=os.environ.get("LAINDOS_WC_VNC"),
                        help="optional QEMU VNC endpoint in addition to the window")
    parser.add_argument("--timeout", type=float, default=20,
                        help="seconds to wait for the shell prompt before launching")
    return parser.parse_args()


def main():
    args = parse_args()
    os.makedirs("build", exist_ok=True)
    if args.reinstall or not os.path.isfile(INSTALLED_IMAGE):
        if not os.path.isfile("vendor/wing-commander_202104/disk1.ima"):
            print("Missing vendor/wing-commander_202104/disk1..3.ima", file=sys.stderr)
            return 1
        install(args.sound)

    remove_if_exists(MONITOR)
    qemu_args = [
        qemu_binary(),
        "-drive", f"file={INSTALLED_IMAGE},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-device", "sb16",
        "-device", "adlib",
    ]
    if not args.no_snapshot:
        qemu_args.append("-snapshot")
    if args.vnc:
        qemu_args.extend(["-vnc", args.vnc])

    print("Starting QEMU with the normal visible display window.")
    if not args.no_snapshot:
        print("Running with QEMU -snapshot; disk writes will be discarded.")

    proc = subprocess.Popen(qemu_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout_chunks = []
    stderr_chunks = []
    stdout_thread = threading.Thread(target=read_stream_live, args=(proc.stdout, stdout_chunks, sys.stdout.buffer), daemon=True)
    stderr_thread = threading.Thread(target=read_stream_live, args=(proc.stderr, stderr_chunks, sys.stderr.buffer), daemon=True)
    stdout_thread.start()
    stderr_thread.start()

    sock = None
    try:
        if not wait_for_output(stdout_chunks, "C:\\>", timeout=args.timeout, stop_markers=()):
            raise TimeoutError("timed out waiting for C:\\>")
        sock = open_monitor(MONITOR)
        if not args.no_launch:
            shell_command(sock, "cd wing")
            time.sleep(1)
            shell_command(sock, "wc")
            print("\nWC launched.")
        else:
            print("\nBooted to shell.")
        print(QUIZ_ANSWERS)
        print("Press Ctrl-C here to stop QEMU.")
        proc.wait()
    except KeyboardInterrupt:
        print("\nStopping QEMU...")
        stop_qemu(proc)
    except Exception as exc:
        print(f"\n{exc}", file=sys.stderr)
        stop_qemu(proc)
        return 1
    finally:
        if sock:
            sock.close()
        stdout_thread.join(timeout=1)
        stderr_thread.join(timeout=1)
    assert proc.returncode is not None
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
