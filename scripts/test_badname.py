#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "badname",
        "BADNAME COM",
        [("tests/programs/badname.asm", "badname.com")],
        required=("PASS: BADNAME CREATE", "PASS: BADNAME MKDIR",
                  "PASS: BADNAME RENAME", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="Create/rename name validation test passed.",
    )


if __name__ == "__main__":
    main()
