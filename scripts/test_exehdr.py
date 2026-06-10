#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "exehdr",
        "EXEHDR  COM",
        [("tests/programs/exehdr.asm", "exehdr.com")],
        required=("PASS: EXEHDR MINALLOC", "PASS: EXEHDR HDRBIG",
                  "PASS: EXEHDR OVLHDR", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="EXE header math guard test passed.",
    )


if __name__ == "__main__":
    main()
