#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "colonpth",
        "COLONPTHCOM",
        [("tests/programs/colonpth.asm", "colonpth.com")],
        required=("PASS: COLONPTH BARE", "PASS: COLONPTH TRAIL",
                  "PASS: COLONPTH VALID", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="Colon path component guard test passed.",
    )


if __name__ == "__main__":
    main()
