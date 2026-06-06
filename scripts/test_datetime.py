#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "datetime",
        "DATETIMECOM",
        [("tests/programs/datetime.asm", "datetime.com")],
        required=("PASS: DATETIME", "Program exited, code=00", "HALT"),
        pass_message="Date/time API test passed.",
    )


if __name__ == "__main__":
    main()
