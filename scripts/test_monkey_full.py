#!/usr/bin/env python3
import os
import signal
import subprocess
import sys

IMG = "build/monkey_full.img"
TIMEOUT = 20


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def run_qemu():
    proc = subprocess.Popen(
        [
            "qemu-system-i386",
            "-drive", f"file={IMG},format=raw",
            "-boot", "order=c",
            "-serial", "stdio",
            "-monitor", "none",
            "-nographic",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        stdout, stderr = proc.communicate(timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        proc.send_signal(signal.SIGTERM)
        try:
            stdout, stderr = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout, stderr = proc.communicate()
    output = stdout.decode("utf-8", errors="replace")
    err = stderr.decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def main():
    if not os.path.exists("vendor/monkey_full.zip"):
        print("Missing vendor/monkey_full.zip", file=sys.stderr)
        sys.exit(1)
    run(["python3", "scripts/build_monkey_full.py"])
    output = run_qemu()
    failed = False
    for marker in ["MiniDOS booted", "EXE loaded", "INT 33h AX=0000"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
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
