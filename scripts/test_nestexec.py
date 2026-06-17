#!/usr/bin/env python3
from testlib import run_simple_serial_test


def main():
    run_simple_serial_test(
        "nestexec",
        "NESTEXECCOM",
        (
            ("tests/programs/nestexec.asm", "nestexec.com"),
            ("tests/programs/nestmid.asm", "nestmid.com"),
            ("tests/programs/nestchd.asm", "nestchd.com"),
        ),
        required=("PASS: NESTEXEC", "Program exited, code=00", "HALT"),
        timeout=15,
        pass_message="Nested EXEC test passed.",
    )


if __name__ == "__main__":
    main()
