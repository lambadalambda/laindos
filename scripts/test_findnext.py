#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, build_nasm_test_image, check_markers, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "findnext.img")
KERNEL = os.path.join(BUILDDIR, "findnext_kernel.bin")
TIMEOUT = 8


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    a_txt = write_fixture("a.txt", b"alpha\n")
    b_txt = write_fixture("b.txt", b"bravo\n")
    aa_txt = write_fixture("aa.txt", b"alpha alpha\n")
    z_com = write_fixture("z.com", b"dummy\n")
    noext = write_fixture("noext", b"extensionless\n")
    build_nasm_test_image(
        BUILDDIR, IMG, KERNEL,
        "FINDNEXTCOM", "tests/programs/findnext.asm", "findnext.com",
        extra_files=(a_txt, b_txt, aa_txt, z_com, noext),
    )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    if not check_markers(output, required=("PASS: FINDNEXT", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nFindNext DTA test passed.")


if __name__ == "__main__":
    main()
