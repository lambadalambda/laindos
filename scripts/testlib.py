#!/usr/bin/env python3
import atexit
import os
import signal
import socket
import subprocess
import sys
import threading
import time


DEFAULT_FAIL_MARKERS = ("FAIL:", "EXC ", "INT 21h AH=")
DEFAULT_STOP_MARKERS = ("HALT",)
DEFAULT_QEMU_VGA = "std,retrace=precise"
REPO_ROOT = os.path.dirname(os.path.dirname(__file__))
DEFAULT_QEMU = os.path.abspath(os.path.join(
    REPO_ROOT,
    "..",
    "qemu-ascendancy",
    "build-asc",
    "qemu-system-i386-unsigned",
))


def build_dir():
    return os.environ.get("LAINDOS_TEST_BUILD_DIR", os.path.join(REPO_ROOT, "build"))


def qemu_binary():
    configured = os.environ.get("LAINDOS_QEMU")
    if configured:
        if os.sep in configured:
            return os.path.abspath(configured)
        return configured
    if os.path.exists(DEFAULT_QEMU):
        return DEFAULT_QEMU
    return "qemu-system-i386"


def qemu_vga():
    return os.environ.get("LAINDOS_QEMU_VGA", DEFAULT_QEMU_VGA)


def qemu_args(args):
    args = list(args)
    if args and args[0] == "qemu-system-i386":
        args[0] = qemu_binary()
    return args


def run_cmd(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def remove_if_exists(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass


def read_stream(stream, chunks):
    try:
        while True:
            data = os.read(stream.fileno(), 4096)
            if not data:
                return
            chunks.append(data)
    except OSError:
        # QEMU teardown can close the pipe while this reader is blocked.
        return


def start_qemu(args):
    proc = subprocess.Popen(
        qemu_args(args),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout_chunks = []
    stderr_chunks = []
    stdout_thread = threading.Thread(target=read_stream, args=(proc.stdout, stdout_chunks), daemon=True)
    stderr_thread = threading.Thread(target=read_stream, args=(proc.stderr, stderr_chunks), daemon=True)
    stdout_thread.start()
    stderr_thread.start()
    atexit.register(kill_qemu_at_exit, proc)
    return proc, stdout_chunks, stderr_chunks, (stdout_thread, stderr_thread)


def kill_qemu_at_exit(proc):
    if proc.poll() is None:
        proc.kill()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            return


def chunks_contain(chunks, markers):
    if not markers:
        return False
    output = b"".join(chunks)
    return any(marker.encode() in output for marker in markers)


def wait_for_output(chunks, marker, timeout=10, stop_markers=DEFAULT_FAIL_MARKERS + DEFAULT_STOP_MARKERS):
    needle = marker.encode()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = b"".join(chunks)
        if needle in output:
            return True
        if any(stop.encode() in output for stop in stop_markers):
            return False
        time.sleep(0.02)
    return False


def open_monitor(path, timeout=8):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    deadline = time.time() + timeout
    while True:
        try:
            sock.connect(path)
            break
        except OSError:
            if time.time() > deadline:
                sock.close()
                raise
            time.sleep(0.1)
    try:
        sock.recv(4096)
    finally:
        sock.settimeout(None)
    return sock


def send_monitor_command(sock, command, delay=0.0):
    sock.sendall(f"{command}\n".encode())
    if delay:
        time.sleep(delay)


def send_monitor_key(sock, key, delay=0.15):
    send_monitor_command(sock, f"sendkey {key}", delay)


def send_monitor_text(sock, text, delay=0.15, keymap=None):
    keys = {" ": "spc", "\\": "backslash", ".": "dot", "-": "minus"}
    if keymap:
        keys.update(keymap)
    for ch in text:
        send_monitor_key(sock, keys.get(ch, ch.lower()), delay)


def monitor_screendump(sock, path, delay=1):
    send_monitor_command(sock, f"screendump {path}")
    if delay:
        time.sleep(delay)


def monitor_quit(sock, proc, timeout=5):
    try:
        send_monitor_command(sock, "quit")
    except OSError:
        pass
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.send_signal(signal.SIGTERM)
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def stop_qemu(proc, grace=3):
    if proc.poll() is not None:
        return
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


def ppm_stats(path):
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        if f.readline().strip() != b"P6":
            return None
        dims = f.readline().split()
        if len(dims) != 2:
            return None
        if f.readline().strip() != b"255":
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


def framebuffer_active(path, label="framebuffer", min_colors=8, min_nonblack=1000):
    stats = ppm_stats(path)
    if stats is None:
        print(f"  FAIL: missing valid {label} screendump")
        return False
    colors, nonblack = stats
    if colors >= min_colors and nonblack > min_nonblack:
        print(f"  PASS: {label} active ({colors} colors, {nonblack} nonblack pixels)")
        return True
    print(f"  FAIL: {label} inactive ({colors} colors, {nonblack} nonblack pixels)")
    return False


def check_markers(output, required=(), forbidden=DEFAULT_FAIL_MARKERS, output_label="QEMU serial output", dump_on_failure=True):
    failed = False
    for marker in required:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in forbidden:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed and dump_on_failure:
        print(f"\n--- {output_label} ---")
        print(output)
        print("--- end ---")
    return not failed


def collect_output(stdout_chunks, stderr_chunks, threads):
    for thread in threads:
        thread.join(timeout=1)
    output = b"".join(stdout_chunks).decode("utf-8", errors="replace")
    err = b"".join(stderr_chunks).decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=10, stop_markers=DEFAULT_STOP_MARKERS, fail_markers=DEFAULT_FAIL_MARKERS):
    deadline = time.monotonic() + timeout
    timed_out = False
    while proc.poll() is None:
        if chunks_contain(stdout_chunks, fail_markers) or chunks_contain(stdout_chunks, stop_markers):
            time.sleep(0.05)
            break
        if time.monotonic() >= deadline:
            timed_out = True
            break
        time.sleep(0.02)
    stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), timed_out


def run_qemu_capture(args, timeout=10, stop_markers=DEFAULT_STOP_MARKERS, fail_markers=DEFAULT_FAIL_MARKERS):
    proc, stdout_chunks, stderr_chunks, threads = start_qemu(args)
    return finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout, stop_markers, fail_markers)
