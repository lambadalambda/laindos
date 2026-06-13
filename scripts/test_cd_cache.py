#!/usr/bin/env python3
"""The CD one-sector read cache stays coherent with shared-buffer reads.

CD_BUF caches the last file sector read, but it is also the scratch
buffer for directory scans, the PVD, and audio. A raw sector read
invalidates the cache, so a FindFirst between two reads of the same file
sector must not let the second read see the directory bytes. Also pins
plain cache-hit re-reads and a sector-crossing read. The cache turns the
MIX archive's many small/repeated reads from one ATAPI fetch each into
CD_BUF hits (a ~19x speedup on the 64-byte-read benchmark under 86Box).
"""
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_cache")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdcache.com")
PATTERN = os.path.join(WORKDIR, "pattern.bin")
IMG = os.path.join(WORKDIR, "cd_cache.img")
ISO = os.path.join(WORKDIR, "cd_cache.iso")
SIZE = 8192
TIMEOUT = 15


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(PATTERN, "wb") as f:
        f.write(bytes(((i ^ (i >> 8)) & 0xFF) for i in range(SIZE)))
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"PATTERN.BIN={PATTERN}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDCACHE COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdcache.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_artifacts()
    output = run_serial_image(IMG, TIMEOUT, extra_args=("-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on"))
    ok = check_markers(
        output,
        required=("PASS: CDCACHE", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD read-cache QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nCD read-cache coherence test passed.")


if __name__ == "__main__":
    main()
