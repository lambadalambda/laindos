#!/usr/bin/env python3
import sys
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "duptest",
        "DUPTEST COM",
        [("tests/programs/duptest.asm", "duptest.com")],
        required=("PASS: DUP", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=45", "INT 21h AH=46"),
        pass_message="Duplicate handle test passed.",
    )


if __name__ == "__main__":
    main()
