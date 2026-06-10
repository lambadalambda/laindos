#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "trunc0",
        "TRUNC0  COM",
        [("tests/programs/trunc0.asm", "trunc0.com")],
        required=("PASS: TRUNC0 SIZE", "PASS: TRUNC0 PERSIST",
                  "PASS: TRUNC0 FREE", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="AH=40h CX=0 truncate test passed.",
    )


if __name__ == "__main__":
    main()
