#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "name83",
        "NAME83  COM",
        [("tests/programs/name83.asm", "name83.com")],
        required=("PASS: NAME83 NINE", "PASS: NAME83 DIR", "PASS: NAME83 LONG",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="8.3 truncation unification test passed.",
    )


if __name__ == "__main__":
    main()
