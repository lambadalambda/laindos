#!/usr/bin/env python3
import argparse
import os
import shlex
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

from sammaxlib import prepare_cd_image
from testlib import qemu_binary, qemu_vga, run_cmd

ARCHIVE = Path(os.environ.get("LAINDOS_SAMMAX_ARCHIVE", "vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip"))
BUILDDIR = Path(os.environ.get("LAINDOS_TEST_BUILD_DIR", "build"))
WORKDIR = BUILDDIR / "sammax_cd"
CUE = WORKDIR / "BG GOLD 3.cue"
BIN = WORKDIR / "BG GOLD 3.bin"
ISO = WORKDIR / "BG_GOLD_3_data.iso"
BOOT = WORKDIR / "run_sammax_boot.bin"
KERNEL = WORKDIR / "run_sammax_kernel.bin"
SHELL = WORKDIR / "shell.com"
FREE = WORKDIR / "free.com"
MEM = WORKDIR / "mem.com"
TIME = WORKDIR / "time.com"
README = WORKDIR / "readme.txt"
C_IMG = Path(os.environ.get("LAINDOS_SAMMAX_C_IMG", str(WORKDIR / "sammax_c.img")))
C_FORMAT = os.environ.get("LAINDOS_SAMMAX_C_FORMAT", "hd160m")


def write_readme():
    README.write_bytes(
        b"LainDOS Sam & Max CD scratch C: drive\r\n"
        b"\r\n"
        b"The Sam & Max CD-ROM is attached as D:.\r\n"
        b"Try: D:, CD \\SAMNMAX, SAMNMAX\r\n"
    )


def build_c_image():
    WORKDIR.mkdir(parents=True, exist_ok=True)
    write_readme()
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
    run_cmd(["python3", "scripts/build_shell_com.py", str(SHELL)])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", str(FREE)])
    shutil.copyfile(FREE, MEM)
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", str(TIME)])
    run_cmd([
        "python3", "scripts/mkimage.py", f"--format={C_FORMAT}", str(BOOT), str(KERNEL), str(C_IMG),
        str(SHELL), str(FREE), str(MEM), str(TIME), str(README),
    ])


def qemu_command():
    return [
        qemu_binary(),
        *shlex.split(os.environ.get("LAINDOS_SAMMAX_QEMU_ARGS", "")),
        "-drive", f"file={C_IMG},format=raw,if=ide,index=0,media=disk",
        "-drive", f"file={ISO},format=raw,if=ide,index=1,media=cdrom,readonly=on",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", "none",
        "-vga", qemu_vga(),
        "-device", "sb16",
        "-device", "adlib",
    ]


def main():
    parser = argparse.ArgumentParser(description="Boot LainDOS with a scratch C: drive and the Sam & Max CD attached as D:.")
    parser.add_argument("--dry-run", action="store_true", help="build images and print the QEMU command without running it")
    args = parser.parse_args()

    if not Path("src/boot.asm").exists():
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)

    prepare_cd_image(WORKDIR, ARCHIVE)
    if os.environ.get("LAINDOS_SAMMAX_REBUILD_C", "1") != "0" or not C_IMG.exists():
        build_c_image()
    cmd = qemu_command()
    print(shlex.join(cmd))
    if args.dry_run:
        return
    try:
        result = subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\nStopping QEMU...")
        sys.exit(130)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
