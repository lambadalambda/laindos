#!/usr/bin/env python3
"""Share-mode opens on the CD release their handle slot on close.

Era programs open read-only files with DOS sharing bits (deny-none read,
AX=3D20h). The close-path flush decision is about the access bits only;
testing the whole mode byte leaks the handle slot on read-only media —
Red Alert's installer exhausted the entire handle table this way and
retried its asset opens forever (black screen, constant CD access).
"""
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_share")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdshare.com")
HELLO = os.path.join(WORKDIR, "hello.txt")
IMG = os.path.join(WORKDIR, "cd_share.img")
ISO = os.path.join(WORKDIR, "cd_share.iso")
TIMEOUT = 15


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(HELLO, "wb") as f:
        f.write(b"Hello from LainDOS CD share test.\r\n")
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"HELLO.TXT={HELLO}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDSHARE COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdshare.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def main():
    build_artifacts()
    output = run_serial_image(IMG, TIMEOUT, extra_args=("-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on"))
    ok = check_markers(
        output,
        required=("PASS: CDSHARE", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD share QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nCD share-mode close test passed.")


if __name__ == "__main__":
    main()
