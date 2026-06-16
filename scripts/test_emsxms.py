#!/usr/bin/env python3
import sys
from testlib import build_simple_test_image, check_markers, run_serial_image


def main():
    img = build_simple_test_image(
        "emsxms",
        "EMSXMS  COM",
        [("tests/programs/emsxms.asm", "emsxms.com")],
    )
    output = run_serial_image(img, timeout=10)
    if not check_markers(output, required=("PASS: EMSXMS", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nEMS/XMS coexistence test passed.")


if __name__ == "__main__":
    main()
