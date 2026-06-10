#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "stdread",
        "STDREAD COM",
        [("tests/programs/stdread.asm", "stdread.com")],
        required=("PASS: STDREAD SEEK", "PASS: STDREAD SEEK5",
                  "PASS: STDREAD READ", "PASS: STDREAD READ5",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="Standard handle read/seek test passed.",
    )


if __name__ == "__main__":
    main()
