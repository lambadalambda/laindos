#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()
TESTFILE = os.path.join(BUILDDIR, "intfile.dat")


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "int24h",
        "INT24H  COM",
        [("tests/programs/int24h.asm", "int24h.com")],
        required=("PASS: INT24H", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="INT 24h wiring test passed.",
    )


if __name__ == "__main__":
    main()
