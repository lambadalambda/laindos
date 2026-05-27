#!/usr/bin/env python3
import atexit
import os
import signal
import subprocess
import sys
import threading
import time


DEFAULT_FAIL_MARKERS = ("FAIL:", "EXC ", "INT 21h AH=")
DEFAULT_STOP_MARKERS = ("HALT",)
REPO_ROOT = os.path.dirname(os.path.dirname(__file__))


def build_dir():
    return os.environ.get("LAINDOS_TEST_BUILD_DIR", os.path.join(REPO_ROOT, "build"))


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
        args,
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


def stop_qemu(proc, grace=3):
    if proc.poll() is not None:
        return
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


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
