#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test

BUILDDIR = build_dir()
BASE1 = os.path.join(BUILDDIR, "PBASE1.DAT")
BASE2 = os.path.join(BUILDDIR, "PBASE2.DAT")


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    with open(BASE1, "wb") as f:
        f.write(b"P")
    with open(BASE2, "wb") as f:
        f.write(b"P")
    run_simple_serial_test(
        "pathbuftest",
        "PATHBUF COM",
        [("tests/programs/pathbuf.asm", "pathbuf.com")],
        extra_files=(BASE1, BASE2),
        required=("PASS: PATHBUF", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:",),
        pass_message="Path buffer overflow test passed.",
    )


if __name__ == "__main__":
    main()
