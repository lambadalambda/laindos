#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "execload",
        "EXECLOADCOM",
        [("tests/programs/execload.asm", "execload.com"),
         ("tests/programs/axchild.asm", "axchild.com"),
         ("tests/programs/lodchild.asm", "lodchild.com")],
        required=("PASS: EXECLOAD AX", "PASS: EXECLOAD BLOCK",
                  "PASS: EXECLOAD RUN", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="EXEC AL=1 load test passed.",
    )


if __name__ == "__main__":
    main()
