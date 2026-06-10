#!/usr/bin/env python3
import os
from testlib import build_dir, run_simple_serial_test


BUILDDIR = build_dir()


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_simple_serial_test(
        "ovlbig",
        "OVLBIG  COM",
        [("tests/programs/ovlbig.asm", "ovlbig.com")],
        required=("PASS: OVLBIG START", "PASS: OVLBIG BELOW",
                  "PASS: OVLBIG ABOVE", "PASS: OVLBIG TAIL",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        timeout=20,
        pass_message="Large overlay 64K boundary test passed.",
    )


if __name__ == "__main__":
    main()
