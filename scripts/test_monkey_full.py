#!/usr/bin/env python3
import os
import signal
import socket
import subprocess
import sys
import tempfile
import time

IMG = "build/monkey_full.img"
TIMEOUT = 25
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-monkey-full.sock")
SCREENSHOT = "build/monkey_full_screen.ppm"


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def run_qemu():
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    try:
        os.unlink(SCREENSHOT)
    except FileNotFoundError:
        pass
    proc = subprocess.Popen(
        [
            "qemu-system-i386",
            "-drive", f"file={IMG},format=raw",
            "-boot", "order=c",
            "-serial", "stdio",
            "-monitor", f"unix:{MONITOR},server,nowait",
            "-vnc", "127.0.0.1:29",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        deadline = time.time() + 8
        while True:
            try:
                sock.connect(MONITOR)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(0.1)
        sock.recv(4096)
        time.sleep(TIMEOUT)
        sock.sendall(f"screendump {SCREENSHOT}\n".encode())
        time.sleep(1)
        sock.sendall(b"quit\n")
        try:
            stdout, stderr = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            proc.send_signal(signal.SIGTERM)
            stdout, stderr = proc.communicate()
    finally:
        sock.close()
    output = stdout.decode("utf-8", errors="replace")
    err = stderr.decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def analyze_screenshot():
    if not os.path.exists(SCREENSHOT):
        return None
    with open(SCREENSHOT, "rb") as f:
        header = f.readline().strip()
        if header != b"P6":
            return None
        dims = f.readline().split()
        if len(dims) != 2:
            return None
        maxval = f.readline().strip()
        if maxval != b"255":
            return None
        pixels = f.read()
    colors = set()
    nonblack = 0
    for i in range(0, len(pixels), 3):
        color = pixels[i:i+3]
        colors.add(color)
        if color != b"\x00\x00\x00":
            nonblack += 1
    return len(colors), nonblack


def main():
    if not os.path.exists("vendor/monkey_full.zip"):
        print("Missing vendor/monkey_full.zip", file=sys.stderr)
        sys.exit(1)
    run(["python3", "scripts/build_monkey_full.py"])
    output = run_qemu()
    failed = False
    for marker in ["MiniDOS booted", "EXE loaded"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    screen = analyze_screenshot()
    if screen is None:
        print("  FAIL: missing valid screendump")
        failed = True
    else:
        colors, nonblack = screen
        if colors >= 8 and nonblack > 1000:
            print(f"  PASS: framebuffer active ({colors} colors, {nonblack} nonblack pixels)")
        else:
            print(f"  FAIL: framebuffer inactive ({colors} colors, {nonblack} nonblack pixels)")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFull Monkey smoke passed.")


if __name__ == "__main__":
    main()
