#!/usr/bin/env python3
"""Tests for the PAUSE, BREAK, MODE, and MORE shell builtins."""
import os
import re
import socket
import subprocess
import sys
import time
from testlib import build_dir, start_qemu, wait_for_output

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "shellbatch.img")
KERNEL = os.path.join(BUILDDIR, "shellbatch_kernel.bin")
MONITOR = os.path.join(BUILDDIR, "shellbatch.sock")
KEY_DELAY = 0.02
KEY_HOLD_MS = 10
PROMPT_RE = re.compile(rb"A:\\[^>\r\n]*>")
KEYMAP = {" ": "spc", "\\": "backslash", ".": "dot", "/": "slash", "-": "minus", "_": "shift-minus", ":": "shift-semicolon", "*": "shift-8", "<": "shift-comma", ">": "shift-dot"}


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "programs/shell.asm", "-o", os.path.join(BUILDDIR, "shell.com")])
    long_lines = []
    for i in range(200):
        long_lines.append(f"LainDOS test data line {i:03d}: this is filler text for the MORE pager test.".encode())
        long_lines.append(b"\r\n")
    with open(os.path.join(BUILDDIR, "longtest.dat"), "wb") as f:
        f.write(b"".join(long_lines))
    with open(os.path.join(BUILDDIR, "moretest.bat"), "wb") as f:
        f.write(b"more < longtest.dat > nul\r\n")
    with open(os.path.join(BUILDDIR, "pausetest.bat"), "wb") as f:
        f.write(b"pause>nul\r\n")
    with open(os.path.join(BUILDDIR, "pausetest2.bat"), "wb") as f:
        f.write(b"pause > nul\r\n")
    with open(os.path.join(BUILDDIR, "modetest.bat"), "wb") as f:
        f.write(b"mode co80>nul\r\n")
    with open(os.path.join(BUILDDIR, "longbat.bat"), "wb") as f:
        for i in range(40):
            f.write(f"echo LONG BATCH FILLER LINE {i:02d}\r\n".encode())
        f.write(b"echo LONG_BATCH_DONE\r\n")
    with open(os.path.join(BUILDDIR, "inner.bat"), "wb") as f:
        f.write(b"echo INNER_BATCH_DONE\r\n")
    with open(os.path.join(BUILDDIR, "outer.bat"), "wb") as f:
        f.write(b"inner.bat\r\necho OUTER_BATCH_DONE\r\n")
    with open(os.path.join(BUILDDIR, "ifgoto.bat"), "wb") as f:
        f.write(
            b"mkdir TESTDIR\r\n"
            b"if exist TESTDIR goto gotdir\r\n"
            b"echo IF_GOTO_FAILED\r\n"
            b":gotdir\r\n"
            b"echo IF_GOTO_DONE\r\n"
            b"if exist TESTDIR barelabel\r\n"
            b"echo IF_BARE_LABEL_FAILED\r\n"
            b":barelabel\r\n"
            b"echo IF_BARE_LABEL_DONE\r\n"
            b"if exist MISSING goto missing\r\n"
            b"echo IF_MISSING_SKIPPED\r\n"
            b":missing\r\n"
        )
    with open(os.path.join(BUILDDIR, "casebat.bat"), "wb") as f:
        f.write(b"echo mixedCaseToken\r\n")
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "shell.com"),
        os.path.join(BUILDDIR, "longtest.dat"),
        os.path.join(BUILDDIR, "moretest.bat"),
        os.path.join(BUILDDIR, "pausetest.bat"),
        os.path.join(BUILDDIR, "pausetest2.bat"),
        os.path.join(BUILDDIR, "modetest.bat"),
        os.path.join(BUILDDIR, "longbat.bat"),
        os.path.join(BUILDDIR, "inner.bat"),
        os.path.join(BUILDDIR, "outer.bat"),
        os.path.join(BUILDDIR, "ifgoto.bat"),
        os.path.join(BUILDDIR, "casebat.bat"),
    ])


def send_monitor_key(sock, key):
    sock.sendall(f"sendkey {key} {KEY_HOLD_MS}\n".encode())
    time.sleep(KEY_DELAY)


def send_text(sock, text):
    for ch in text:
        if ch.isalnum():
            key = ch.lower()
        elif ch in KEYMAP:
            key = KEYMAP[ch]
        else:
            raise ValueError(f"unmapped QEMU key for {ch!r} in {text!r}")
        send_monitor_key(sock, key)


def prompt_count(output_chunks):
    return len(PROMPT_RE.findall(b"".join(output_chunks)))


def wait_for_prompt_count(output_chunks, count, timeout=8, context="prompt"):
    deadline = time.monotonic() + timeout
    stop_markers = ("FAIL:", "EXC ", "INT 21h AH=", "HALT")
    while time.monotonic() < deadline:
        output = b"".join(output_chunks)
        if len(PROMPT_RE.findall(output)) >= count:
            return
        for marker in stop_markers:
            if marker.encode() in output:
                raise RuntimeError(f"saw {marker!r} while waiting for {context}")
        time.sleep(0.02)
    raise TimeoutError(f"timed out waiting for {context}")


def wait_for_output_since(output_chunks, marker, start_len, timeout=8):
    if isinstance(marker, bytes):
        needle = marker
    else:
        needle = marker.encode()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = b"".join(output_chunks)
        if needle in output[start_len:]:
            return True
        time.sleep(0.02)
    return False


def send_command(sock, output_chunks, command, timeout=8):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    send_text(sock, command)
    send_monitor_key(sock, "ret")
    wait_for_prompt_count(output_chunks, target_prompt, timeout=timeout, context=f"prompt after {command!r}")
    return b"".join(output_chunks)[start_len:]


def send_paged_command(sock, output_chunks, command, marker=b"Press any key to continue", timeout=30):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    seen_markers = 0
    send_text(sock, command)
    send_monitor_key(sock, "ret")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = b"".join(output_chunks)
        if prompt_count(output_chunks) >= target_prompt:
            return output[start_len:]
        for stop_marker in (b"FAIL:", b"EXC ", b"INT 21h AH=", b"HALT"):
            if stop_marker in output[start_len:]:
                raise RuntimeError(f"saw {stop_marker!r} while waiting for {command!r}")
        marker_count = output[start_len:].count(marker)
        if marker_count > seen_markers:
            seen_markers = marker_count
            send_monitor_key(sock, "ret")
        time.sleep(0.02)
    raise TimeoutError(f"timed out waiting for prompt after {command!r}")


def require_command_output(command, output, expected=(), unexpected=()):
    failed = False
    for marker in expected:
        if marker.encode() not in output:
            print(f"  FAIL: {command!r} output missing {marker!r}")
            failed = True
        else:
            print(f"  PASS: {command!r} output contains {marker!r}")
    for marker in unexpected:
        if marker.encode() in output:
            print(f"  FAIL: {command!r} output unexpectedly contained {marker!r}")
            failed = True
    return not failed


def test_pause_builtin(sock, output_chunks):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    send_text(sock, "pause")
    send_monitor_key(sock, "ret")
    if not wait_for_output_since(output_chunks, b"Press any key to continue", start_len, timeout=8):
        print("Output so far:", b"".join(output_chunks)[-500:])
        raise RuntimeError("PAUSE did not print prompt")
    send_monitor_key(sock, "ret")
    wait_for_prompt_count(output_chunks, target_prompt, timeout=8, context="prompt after PAUSE")
    output = b"".join(output_chunks)[start_len:]
    if b"Press any key to continue" not in output:
        print("  FAIL: PAUSE did not print prompt")
        return False
    print("  PASS: PAUSE printed prompt and waited for keypress")
    return True


def test_pause_redirect_nospace(sock, output_chunks):
    start_len = len(b"".join(output_chunks))
    send_text(sock, "pausetest")
    send_monitor_key(sock, "ret")
    time.sleep(2.0)
    send_monitor_key(sock, "ret")
    time.sleep(1.5)
    output = b"".join(output_chunks)[start_len:]
    if b"Press any key to continue" in output:
        print("  FAIL: pausetest printed prompt (expected quiet redirect)")
        return False
    if b"A:\\>" not in output and prompt_count(output_chunks) < 1:
        print("  FAIL: pausetest did not return to prompt")
        return False
    print("  PASS: pausetest batch (pause>nul) suppressed prompt")
    return True


def test_pause_redirect_space(sock, output_chunks):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    sock.sendall(b"pausetest2\r")
    time.sleep(1.0)
    send_monitor_key(sock, "ret")
    time.sleep(1.5)
    output = b"".join(output_chunks)[start_len:]
    if b"Press any key to continue" in output:
        print("  FAIL: pausetest2 printed prompt (expected quiet redirect)")
        return False
    if prompt_count(output_chunks) < target_prompt:
        print("  FAIL: pausetest2 did not return to prompt")
        return False
    print("  PASS: pausetest2 batch (pause > nul) suppressed prompt")
    return True


def test_break_builtin(sock, output_chunks):
    output = send_command(sock, output_chunks, "break on")
    if not require_command_output("break on", output, [], ["Bad command"]):
        return False
    print("  PASS: BREAK ON accepted")
    output = send_command(sock, output_chunks, "break off")
    if not require_command_output("break off", output, [], ["Bad command"]):
        return False
    print("  PASS: BREAK OFF accepted")
    return True


def test_mode_co80(sock, output_chunks):
    output = send_command(sock, output_chunks, "mode co80")
    if b"Bad command" in output:
        print("  FAIL: MODE CO80 rejected as bad command")
        return False
    if b"is the current mode" not in output:
        print("  FAIL: MODE CO80 did not print status message")
        return False
    print("  PASS: MODE CO80 accepted and printed status")
    return True


def test_mode_redirect_nul(sock, output_chunks):
    target_prompt = prompt_count(output_chunks) + 1
    start_len = len(b"".join(output_chunks))
    sock.sendall(b"modetest\r")
    time.sleep(1.0)
    send_monitor_key(sock, "ret")
    time.sleep(1.5)
    output = b"".join(output_chunks)[start_len:]
    if b"is the current mode" in output:
        print("  FAIL: modetest printed status (expected quiet redirect)")
        return False
    if prompt_count(output_chunks) < target_prompt:
        print("  FAIL: modetest did not return to prompt")
        return False
    print("  PASS: modetest batch (mode co80>nul) suppressed status")
    return True


def test_more_builtin(sock, output_chunks):
    output = send_paged_command(sock, output_chunks, "more < longtest.dat", marker=b"-- More --")
    if b"-- More --" not in output:
        print("  FAIL: MORE did not show -- More -- prompt")
        return False
    print("  PASS: MORE < longtest.dat shows -- More -- and waits for keypress")
    if b"LainDOS test data line" not in output:
        print("  FAIL: MORE did not print file content")
        return False
    print("  PASS: MORE < longtest.dat printed file content")
    if b"LainDOS test data line 199" not in output:
        print("  FAIL: MORE did not print content after the first 4 KiB read")
        return False
    print("  PASS: MORE < longtest.dat printed content after the first 4 KiB read")
    return True


def test_more_missing_arg(sock, output_chunks):
    output = send_command(sock, output_chunks, "more")
    if b"Bad command" in output:
        print("  FAIL: MORE rejected as bad command")
        return False
    print("  PASS: MORE without args did not error out")
    return True


def test_more_from_batch(sock, output_chunks):
    output = send_command(sock, output_chunks, "moretest")
    if b"Bad command" in output:
        print("  FAIL: batch that uses MORE < longtest.dat > nul was rejected")
        return False
    if b"LainDOS test data line" in output:
        print("  FAIL: batch printed file content even though it was redirected to nul")
        return False
    print("  PASS: batch invoked MORE < longtest.dat > nul without errors")
    return True


def test_long_batch_file(sock, output_chunks):
    output = send_command(sock, output_chunks, "longbat", timeout=12)
    if b"LONG_BATCH_DONE" not in output:
        print("  FAIL: long batch did not continue past first buffer")
        return False
    if b"Bad command" in output:
        print("  FAIL: long batch hit a bad command")
        return False
    print("  PASS: long batch continued past first buffer")
    return True


def test_nested_batch_file(sock, output_chunks):
    output = send_command(sock, output_chunks, "outer")
    if b"INNER_BATCH_DONE" not in output:
        print("  FAIL: nested batch did not run inner batch")
        return False
    if b"OUTER_BATCH_DONE" not in output:
        print("  FAIL: outer batch did not resume after inner batch")
        return False
    if b"Bad command" in output:
        print("  FAIL: nested batch hit a bad command")
        return False
    print("  PASS: nested batch ran inner batch and resumed outer batch")
    return True


def test_if_goto_labels(sock, output_chunks):
    output = send_command(sock, output_chunks, "ifgoto", timeout=12)
    expected = (b"IF_GOTO_DONE", b"IF_BARE_LABEL_DONE", b"IF_MISSING_SKIPPED")
    for marker in expected:
        if marker not in output:
            print(f"  FAIL: ifgoto output missing {marker.decode()}")
            return False
    unexpected = (b"IF_GOTO_FAILED", b"IF_BARE_LABEL_FAILED", b"Bad command")
    for marker in unexpected:
        if marker in output:
            print(f"  FAIL: ifgoto output unexpectedly contained {marker.decode()}")
            return False
    print("  PASS: IF EXIST, GOTO, labels, and bare-label branch worked")
    return True


def test_batch_preserves_case(sock, output_chunks):
    output = send_command(sock, output_chunks, "casebat")
    if b"mixedCaseToken" not in output:
        print("  FAIL: batch output did not preserve argument case")
        return False
    if b"MIXEDCASETOKEN" in output:
        print("  FAIL: batch output was uppercased")
        return False
    print("  PASS: batch command arguments preserve case")
    return True


def main():
    build_image()
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-nographic",
    ])
    sock = None
    try:
        deadline = time.time() + 8
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        while True:
            try:
                sock.connect(MONITOR)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(0.1)
        sock.recv(4096)
        if not wait_for_output(stdout_chunks, "LainDOS Shell", timeout=15,
                               stop_markers=("EXC ", "INT 21h AH=", "Runtime error 200", "HALT")):
            print("FAIL: shell did not boot")
            sys.exit(1)
        sock.settimeout(None)
        results = []
        results.append(test_pause_builtin(sock, stdout_chunks))
        results.append(test_pause_redirect_nospace(sock, stdout_chunks))
        results.append(test_pause_redirect_space(sock, stdout_chunks))
        results.append(test_break_builtin(sock, stdout_chunks))
        results.append(test_mode_co80(sock, stdout_chunks))
        results.append(test_mode_redirect_nul(sock, stdout_chunks))
        results.append(test_more_builtin(sock, stdout_chunks))
        results.append(test_more_missing_arg(sock, stdout_chunks))
        results.append(test_more_from_batch(sock, stdout_chunks))
        results.append(test_long_batch_file(sock, stdout_chunks))
        results.append(test_nested_batch_file(sock, stdout_chunks))
        results.append(test_if_goto_labels(sock, stdout_chunks))
        results.append(test_batch_preserves_case(sock, stdout_chunks))
        if not all(results):
            print("\nShell batch-builtin test FAILED")
            sys.exit(1)
        print("\nShell batch-builtin test passed.")
    finally:
        if sock is not None:
            try:
                send_text(sock, "exit")
                send_monitor_key(sock, "ret")
            except Exception:
                pass
            try:
                sock.close()
            except Exception:
                pass
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
