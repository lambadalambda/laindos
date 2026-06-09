#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_find")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdfind.com")
HELLO = os.path.join(WORKDIR, "hello.txt")
README = os.path.join(WORKDIR, "readme.txt")
IMG = os.path.join(WORKDIR, "cd_find.img")
ISO = os.path.join(WORKDIR, "cd_find.iso")
TIMEOUT = 10


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(HELLO, "wb") as f:
        f.write(b"Hello from LainDOS CD-ROM find test.\r\n")
    with open(README, "wb") as f:
        f.write(b"Second CD-ROM directory entry.\r\n")
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"HELLO.TXT={HELLO}", f"README.TXT={README}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDFIND  COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdfind.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_artifacts()
    output, _ = run_qemu_capture([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    ok = check_markers(
        output,
        required=("PASS: CDFIND", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD find QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nCD find test passed.")


if __name__ == "__main__":
    main()
