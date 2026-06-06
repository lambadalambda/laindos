#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "attrapi",
        "ATTRAPI COM",
        [("tests/programs/attrapi.asm", "attrapi.com")],
        required=("PASS: ATTRAPI", "Program exited, code=00", "HALT"),
        pass_message="Attribute API test passed.",
    )


if __name__ == "__main__":
    main()
