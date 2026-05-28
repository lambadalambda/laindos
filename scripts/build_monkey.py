#!/usr/bin/env python3
"""Build Monkey Island demo disk image for LainDOS testing."""
import subprocess
import sys
import os

BUILDDIR = "build"
VENDORDIR = "vendor"
MONKEY_KERNEL = f"{BUILDDIR}/monkey_kernel.bin"
MONKEY_IMG = f"{BUILDDIR}/monkey.img"

def main():
    os.makedirs(BUILDDIR, exist_ok=True)

    # Build all components
    for src, out in [
        ("src/boot.asm", f"{BUILDDIR}/boot.bin"),
        ("src/kernel.asm", MONKEY_KERNEL),
        ("tests/programs/hello.asm", f"{BUILDDIR}/hello.com"),
        ("tests/programs/helloexe.asm", f"{BUILDDIR}/hello.exe"),
        ("tests/programs/filetest.asm", f"{BUILDDIR}/filetest.exe"),
        ("tests/programs/memtest.asm", f"{BUILDDIR}/memtest.exe"),
        ("tests/programs/closetest.asm", f"{BUILDDIR}/close.exe"),
        ("tests/programs/regtest.asm", f"{BUILDDIR}/regtest.exe"),
        ("tests/programs/mousetest.asm", f"{BUILDDIR}/mouse.exe"),
        ("tests/programs/mousehw.asm", f"{BUILDDIR}/mousehw.exe"),
        ("tests/programs/miiotest.asm", f"{BUILDDIR}/miiotest.exe"),
        ("tests/programs/writetest.asm", f"{BUILDDIR}/write.exe"),
    ]:
        cmd = ["nasm", "-f", "bin", src, "-o", out]
        if src == "src/kernel.asm":
            cmd.insert(1, '-DBOOT_FILE="MIDEMO  EXE"')
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode != 0:
            print(f"NASM error for {src}: {r.stderr}", file=sys.stderr)
            sys.exit(1)

    # Generate test data files
    subprocess.run(["python3", "scripts/mktestfile.py", f"{BUILDDIR}/testfile.dat"], check=True)
    subprocess.run(["python3", "scripts/mksubtest.py", f"{BUILDDIR}/subtest.dat"], check=True)

    # Build disk image with Monkey Island demo files
    cmd = [
        "python3", "scripts/mkimage.py",
        f"{BUILDDIR}/boot.bin",
        MONKEY_KERNEL,
        MONKEY_IMG,
        f"{BUILDDIR}/hello.com",
        f"{BUILDDIR}/hello.exe",
        f"{BUILDDIR}/filetest.exe",
        f"{BUILDDIR}/memtest.exe",
        f"{BUILDDIR}/close.exe",
        f"{BUILDDIR}/regtest.exe",
        f"{BUILDDIR}/mouse.exe",
        f"{BUILDDIR}/mousehw.exe",
        f"{BUILDDIR}/miiotest.exe",
        f"{BUILDDIR}/write.exe",
        f"{BUILDDIR}/testfile.dat",
        f"MIDEMO:{BUILDDIR}/subtest.dat",
    ]

    # Add Monkey Island demo files to root directory
    mi_files = [
        ("midemo.exe", "vendor/midemo.exe"),
        ("disk01.lec", "vendor/disk01.lec"),
        ("000.lfl", "vendor/000.lfl"),
        ("901.lfl", "vendor/901.lfl"),
        ("902.lfl", "vendor/902.lfl"),
        ("904.lfl", "vendor/904.lfl"),
        ("monkey.txt", "vendor/monkey.txt"),
        ("readme", "vendor/readme"),
    ]

    missing = []
    for name, path in mi_files:
        if os.path.exists(path):
            cmd.append(path)
        else:
            missing.append(path)

    if missing:
        print("Missing Monkey Island vendor files:", file=sys.stderr)
        for path in missing:
            print(f"  {path}", file=sys.stderr)
        sys.exit(1)

    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout, end="")
    if r.stderr:
        print(r.stderr, end="", file=sys.stderr)
    if r.returncode != 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
