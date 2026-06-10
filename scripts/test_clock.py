#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "clock",
        "CLOCK   COM",
        [("tests/programs/clock.asm", "clock.com")],
        required=("PASS: CLOCK SET", "PASS: CLOCK ADVANCE",
                  "PASS: CLOCK MIDNIGHT", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        timeout=15,
        pass_message="DOS clock test passed.",
    )


if __name__ == "__main__":
    main()
