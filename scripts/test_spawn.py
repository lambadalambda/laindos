#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "spawn.img")
KERNEL = os.path.join(BUILDDIR, "spawn_kernel.bin")
TIMEOUT = 10


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    child = os.path.join(BUILDDIR, "spawnch.com")
    data = os.path.join(BUILDDIR, "spawndat.txt")
    run_cmd(["nasm", "-f", "bin", "tests/programs/spawnch.asm", "-o", child])
    with open(data, "wb") as f:
        f.write(b"SPAWN! inherited handle data\r\n")
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "SPAWN   COM", "tests/programs/spawn.asm", "spawn.com",
        extra_files=(child, data),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: SPAWNCH", "PASS: SPAWN", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nLauncher spawn inheritance test passed.")


if __name__ == "__main__":
    main()
