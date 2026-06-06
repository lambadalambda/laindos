#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "compatapi",
        "COMPATAPCOM",
        [("tests/programs/compatapi.asm", "compatap.com")],
        required=("PASS: COMPATAPI", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=50", "INT 21h AH=5D",
                   "INT 21h AH=60", "INT 21h AH=66", "INT 21h AH=71"),
        pass_message="Compatibility API test passed.",
    )


if __name__ == "__main__":
    main()
