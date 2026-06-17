#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "emsmap40",
        "EMSMAP40COM",
        [("tests/programs/emsmap40.asm", "emsmap40.com")],
        required=("PASS: EMSMAP40", "Program exited, code=00", "HALT"),
        pass_message="EMS 4.0 map/unmap test passed.",
    )


if __name__ == "__main__":
    main()
