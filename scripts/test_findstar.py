#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "findstar.img")
KERNEL = os.path.join(BUILDDIR, "findstar_kernel.bin")
TIMEOUT = 8


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    a_txt = write_fixture("a.txt", b"alpha\n")
    b = write_fixture("b", b"bravo\n")
    b_exe = write_fixture("b.exe", b"bravo exe\n")
    c_exe = write_fixture("c.exe", b"charlie exe\n")
    build_nasm_test_image(
        BUILDDIR,
        IMG,
        KERNEL,
        "FINDSTARCOM",
        "tests/programs/findstar.asm",
        "findstar.com",
        extra_files=(a_txt, b, b_exe, c_exe),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: FINDSTAR", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nFind star wildcard test passed.")


if __name__ == "__main__":
    main()
