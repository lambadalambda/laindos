#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "dosstruct",
        "DOSSTRUCCOM",
        [("tests/programs/dosstruct.asm", "dosstruct.com")],
        required=("PASS: DOSSTRUCT", "Program exited, code=00", "HALT"),
        pass_message="DOS structure API test passed.",
    )


if __name__ == "__main__":
    main()
