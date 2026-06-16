#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "createapi",
        "CREATEAPCOM",
        [("tests/programs/createapi.asm", "createap.com")],
        required=("PASS: CREATEAPI", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=5A", "INT 21h AH=5B", "INT 21h AH=67", "INT 21h AH=6C"),
        pass_message="Create API test passed.",
    )


if __name__ == "__main__":
    main()
