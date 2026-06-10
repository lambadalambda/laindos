#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "hma",
        "HMA     COM",
        [("tests/programs/hma.asm", "hma.com")],
        required=("PASS: HMA VEC", "PASS: HMA A20", "PASS: HMA MEM",
                  "PASS: HMA XMS", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="HMA kernel relocation test passed.",
    )


if __name__ == "__main__":
    main()
