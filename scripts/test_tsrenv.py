#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "tsrenv",
        "TSRENV  COM",
        [("tests/programs/tsrenv.asm", "tsrenv.com"),
         ("tests/programs/tsrenvc.asm", "tsrenvc.com"),
         ("tests/programs/hello.asm", "hello.com")],
        required=("PASS: TSRENVC", "PASS: TSRENV KEPT",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="TSR environment residency test passed.",
    )


if __name__ == "__main__":
    main()
