#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "dbcs",
        "DBCS    COM",
        [("tests/programs/dbcs.asm", "dbcs.com")],
        required=("PASS: DBCS", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=63"),
        pass_message="DBCS test passed.",
    )


if __name__ == "__main__":
    main()
