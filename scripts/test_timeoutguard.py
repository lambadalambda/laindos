#!/usr/bin/env python3
"""A hung image must fail run_serial_image even after printing its markers."""
import os
import subprocess
import sys
from testlib import build_dir, build_nasm_test_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "timeoutguard.img")
KERNEL = os.path.join(BUILDDIR, "timeoutguard_kernel.bin")


def main():
    build_nasm_test_image(BUILDDIR, IMG, KERNEL, "HANGLOOPCOM",
                          "tests/programs/hangloop.asm", "hangloop.com")
    probe = (
        "import sys; sys.path.insert(0, 'scripts'); "
        "from testlib import run_serial_image; "
        f"out = run_serial_image({IMG!r}, timeout=4); "
        "print('UNREACHABLE' if 'PASS: HANGLOOP' in out else 'NO MARKER')"
    )
    result = subprocess.run([sys.executable, "-c", probe],
                            capture_output=True, text=True)
    if result.returncode == 0:
        print("FAIL: run_serial_image accepted a hung image")
        print(result.stdout)
        sys.exit(1)
    if "without reaching a stop marker" not in result.stdout:
        print("FAIL: timeout failure did not explain itself")
        print(result.stdout)
        sys.exit(1)
    print("  PASS: hung image failed with a clear timeout message")
    print("\nTimeout guard test passed.")


if __name__ == "__main__":
    main()
