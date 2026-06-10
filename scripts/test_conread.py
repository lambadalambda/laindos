#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "conread",
        "CONREAD COM",
        [("tests/programs/conread.asm", "conread.com")],
        required=("PASS: CONREAD LINE", "PASS: CONREAD BS", "PASS: CONREAD EXT",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="CON handle line-buffered read test passed.",
    )


if __name__ == "__main__":
    main()
