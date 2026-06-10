#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "envbig",
        "ENVBIG  COM",
        [("tests/programs/envbig.asm", "envbig.com"),
         ("tests/programs/envchild.asm", "envchild.com")],
        required=("PASS: ENVCHILD", "PASS: ENVBIG",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="Large EXEC environment test passed.",
    )


if __name__ == "__main__":
    main()
