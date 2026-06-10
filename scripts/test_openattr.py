#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "openattr",
        "OPENATTRCOM",
        [("tests/programs/openattr.asm", "openattr.com")],
        required=("PASS: OPENATTR DIR", "PASS: OPENATTR RO",
                  "PASS: OPENATTR SHARE", "PASS: OPENATTR WRITE",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        pass_message="Open attribute/access check test passed.",
    )


if __name__ == "__main__":
    main()
