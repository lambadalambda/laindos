#!/usr/bin/env python3
import sys
from testlib import build_simple_test_image, check_markers, run_serial_image


def main():
    img = build_simple_test_image(
        "exectail",
        "EXECTAILCOM",
        [
            ("tests/programs/exectail.asm", "exectail.com"),
            ("tests/programs/tailchk.asm", "tailchk.com"),
        ],
    )
    output = run_serial_image(img, timeout=10)
    if not check_markers(output, required=("PASS: TAILCHK", "PASS: EXECTAIL", "Program exited, code=00", "HALT")):
        sys.exit(1)
    if output.count("PASS: TAILCHK") != 2:
        print("  FAIL: expected two TAILCHK child runs")
        sys.exit(1)
    print("  PASS: found two TAILCHK child runs")
    print("\nEXEC command-tail bounds test passed.")


if __name__ == "__main__":
    main()
