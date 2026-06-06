#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "committest",
        "COMMIT  COM",
        [("tests/programs/committest.asm", "commit.com")],
        required=("PASS: COMMIT", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=68"),
        pass_message="Commit file test passed.",
    )


if __name__ == "__main__":
    main()
