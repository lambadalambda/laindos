#!/usr/bin/env python3
import sys
from testlib import build_simple_test_image, check_markers, run_serial_image


def main():
    img = build_simple_test_image(
        "emslarge",
        "EMSLARGECOM",
        [("tests/programs/emslarge.asm", "emslarge.com")],
    )
    output = run_serial_image(img, timeout=10)
    if not check_markers(output, required=("PASS: EMSLARGE", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nLarge EMS allocation test passed.")


if __name__ == "__main__":
    main()
