#!/usr/bin/env python3
import argparse
import os
import shutil
import sys
from pathlib import Path

from testlib import build_dir, check_markers, finish_qemu, run_cmd, start_qemu

BUILDDIR = Path(build_dir())
WORKDIR = BUILDDIR / "cd_86box"
PROFILE = WORKDIR / "profile"
BOOT = WORKDIR / "boot.bin"
KERNEL = WORKDIR / "kernel.bin"
PROGRAM = WORKDIR / "cdfile.com"
BOOT_PROGRAM = WORKDIR / "hello.com"
HELLO = WORKDIR / "hello.txt"
FLOPPY_IMG = WORKDIR / "cd_86box.img"
ISO = WORKDIR / "cd_86box.iso"
CONFIG = PROFILE / "86box.cfg"
TIMEOUT = int(os.environ.get("LAINDOS_86BOX_TIMEOUT", "45"))
DEFAULT_86BOX = "/Applications/86Box.app/Contents/MacOS/86Box"


def build_artifacts(boot_only=False):
    WORKDIR.mkdir(parents=True, exist_ok=True)
    if not boot_only:
        HELLO.write_bytes(b"Hello from LainDOS CD-ROM file test.\r\n")
        run_cmd(["python3", "scripts/mkiso.py", str(ISO), f"HELLO.TXT={HELLO}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    if boot_only:
        run_cmd(["nasm", '-DBOOT_FILE="HELLO   COM"', "-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
        run_cmd(["nasm", "-f", "bin", "tests/programs/hello.asm", "-o", str(BOOT_PROGRAM)])
        run_cmd(["python3", "scripts/mkimage.py", str(BOOT), str(KERNEL), str(FLOPPY_IMG), str(BOOT_PROGRAM)])
    else:
        run_cmd(["nasm", '-DBOOT_FILE="CDFILE  COM"', "-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
        run_cmd(["nasm", "-f", "bin", "tests/programs/cdfile.asm", "-o", str(PROGRAM)])
        run_cmd(["python3", "scripts/mkimage.py", str(BOOT), str(KERNEL), str(FLOPPY_IMG), str(PROGRAM)])


def build_profile(with_cd=True):
    shutil.rmtree(PROFILE, ignore_errors=True)
    PROFILE.mkdir(parents=True, exist_ok=True)
    cd_block = ""
    if with_cd:
        cd_block = f"""cdrom_01_ide_channel = 1:0
cdrom_01_image_path = {ISO.resolve()}
cdrom_01_parameters = 1, atapi
"""
    CONFIG.write_text(f"""[General]
emu_build_num = 9001
vid_renderer = qt_software

[Machine]
cpu_family = pentium_p54c
cpu_multi = 1.5
cpu_speed = 75000000
cpu_use_dynarec = 1
fpu_type = internal
machine = p54tp4xe
mem_size = 8192

[Video]
gfxcard = s3_trio32_pci

[Input devices]
keyboard_type = keyboard_at
mouse_type = ps2

[Network]
net_01_link = 0
net_02_link = 0
net_03_link = 0
net_04_link = 0

[Storage controllers]
hdc_1 = ide_pci

[Ports (COM & LPT)]
serial1_device = stdio

[Virtual Console (COM) #1]
mode = 0

[Floppy and CD-ROM drives]
{cd_block}fdd_01_type = 35_2hd
fdd_host_buffering = 1
""", encoding="ascii")


def main():
    parser = argparse.ArgumentParser(description="Run focused LainDOS CD smoke under 86Box.")
    parser.add_argument("--boot-only", action="store_true", help="boot HELLO.COM from floppy with no hard disk and no CD")
    args = parser.parse_args()
    exe = os.environ.get("LAINDOS_86BOX", DEFAULT_86BOX)
    if not os.path.exists(exe):
        print(f"Missing 86Box executable: {exe}", file=sys.stderr)
        sys.exit(1)
    build_artifacts(boot_only=args.boot_only)
    build_profile(with_cd=not args.boot_only)
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        exe,
        "-P", str(PROFILE.resolve()),
        "-I", f"a:{FLOPPY_IMG.resolve()}",
        "-N",
    ])
    output, timed_out = finish_qemu(
        proc,
        stdout_chunks,
        stderr_chunks,
        threads,
        timeout=TIMEOUT,
        stop_markers=("PASS: HELLO.COM" if args.boot_only else "PASS: CDFILE", "HALT"),
    )
    required = ("PASS: HELLO.COM", "Program exited, code=00", "HALT") if args.boot_only else ("PASS: CDFILE", "Program exited, code=00", "HALT")
    ok = check_markers(
        output,
        required=required,
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="86Box boot serial output" if args.boot_only else "CD file 86Box serial output",
    )
    if timed_out:
        print(f"  FAIL: 86Box timed out after {TIMEOUT}s")
        ok = False
    if not ok:
        sys.exit(1)
    if args.boot_only:
        print("\n86Box boot-only test passed.")
    else:
        print("\nCD file 86Box test passed.")


if __name__ == "__main__":
    main()
