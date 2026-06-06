#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test

BUILDDIR = build_dir()
ROOTFILE = os.path.join(BUILDDIR, "FFROOT.DAT")


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(ROOTFILE, "wb") as f:
        f.write(b"R")
    run_simple_serial_test(
        "ffroottest",
        "FFROOT  COM",
        [("tests/programs/ffroot.asm", "ffroot.com")],
        extra_files=(ROOTFILE,),
        required=("PASS: FFROOT", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:",),
        pass_message="FindFirst rooted path test passed.",
    )


if __name__ == "__main__":
    main()
