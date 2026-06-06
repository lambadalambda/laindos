#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "execsegtest",
        "EXECSEG COM",
        [
            ("tests/programs/execseg.asm", "execseg.com"),
            ("tests/programs/envchild.asm", "envchild.com"),
        ],
        required=("PASS: EXECSEG", "PASS: ENVCHILD", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:",),
        pass_message="EXEC env segment validation test passed.",
    )


if __name__ == "__main__":
    main()
