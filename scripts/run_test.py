#!/usr/bin/env python3
import subprocess
import sys
import time


def main():
    if len(sys.argv) < 2:
        print("usage: run_test.py COMMAND [ARG ...]", file=sys.stderr)
        return 2
    start = time.monotonic()
    try:
        return subprocess.run(sys.argv[1:]).returncode
    finally:
        elapsed = time.monotonic() - start
        label = " ".join(sys.argv[1:])
        print(f"TIME: {label} {elapsed:.2f}s")


if __name__ == "__main__":
    sys.exit(main())
