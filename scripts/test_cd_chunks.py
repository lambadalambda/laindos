#!/usr/bin/env python3
"""CD file reads across chunk-size classes against a patterned file.

Pins byte-exact behavior of the read path's slow (sub-sector, bounce
buffer) and fast (multi-sector, direct into the caller's buffer) lanes,
the boundaries between them, EOF, and a post-seek unaligned read.
"""
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_chunks")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdchunks.com")
PATTERN = os.path.join(WORKDIR, "pattern.bin")
IMG = os.path.join(WORKDIR, "cd_chunks.img")
ISO = os.path.join(WORKDIR, "cd_chunks.iso")
SIZE = 200001
TIMEOUT = 180


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    data = bytes((i ^ (i >> 8) ^ (i >> 16)) & 0xFF for i in range(SIZE))
    with open(PATTERN, "wb") as f:
        f.write(data)
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"PATTERN.BIN={PATTERN}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDCHUNKSCOM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdchunks.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_artifacts()
    output = run_serial_image(IMG, TIMEOUT, extra_args=("-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on"))
    ok = check_markers(
        output,
        required=("PASS: CDCHUNKS", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD chunks QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nCD chunks test passed.")


if __name__ == "__main__":
    main()
