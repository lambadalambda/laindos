#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test

BUILDDIR = build_dir()
TESTFILE = os.path.join(BUILDDIR, "fcbfile.txt")


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(TESTFILE, "wb") as f:
        f.write(b"FCB find test data\r\n")
    run_simple_serial_test(
        "fcbfind",
        "FCBFIND COM",
        [("tests/programs/fcbfind.asm", "fcbfind.com")],
        extra_files=(TESTFILE,),
        required=("PASS: FCBFIND", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=11", "INT 21h AH=12"),
        pass_message="FCB find test passed.",
    )


if __name__ == "__main__":
    main()
