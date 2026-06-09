#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_exec")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdexec.com")
HELLO_COM = os.path.join(WORKDIR, "cdhello.com")
HELLO_EXE = os.path.join(WORKDIR, "hello.exe")
OVERLAY_EXE = os.path.join(WORKDIR, "overlay.exe")
IMG = os.path.join(WORKDIR, "cd_exec.img")
ISO = os.path.join(WORKDIR, "cd_exec.iso")
TIMEOUT = 10


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    run_cmd(["nasm", "-f", "bin", "tests/programs/hello.asm", "-o", HELLO_COM])
    run_cmd(["nasm", "-f", "bin", "tests/programs/helloexe.asm", "-o", HELLO_EXE])
    run_cmd(["nasm", "-f", "bin", "tests/programs/overlay.asm", "-o", OVERLAY_EXE])
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"CDHELLO.COM={HELLO_COM}", f"SUBDIR/HELLO.EXE={HELLO_EXE}", f"SUBDIR/OVERLAY.EXE={OVERLAY_EXE}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDEXEC  COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdexec.asm", "-o", PROGRAM])
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
        required=("PASS: HELLO.COM", "PASS: HELLO.EXE", "PASS: CDEXEC", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD EXEC QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    print("\nCD EXEC test passed.")


if __name__ == "__main__":
    main()
