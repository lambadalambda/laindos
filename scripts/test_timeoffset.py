#!/usr/bin/env python3
import os
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
TIMEOUT = 8


CASES = [
    ("zero", 0, 0, 0, 0, 0),
    ("plus150", 150, 0, 0, 2, 30),
    ("minus60", -60, 0, 0, 23, 0),
    ("wrap2350plus20", 20, 23, 50, 0, 10),
]


def build_image(label, offset_minutes, base_hour, base_min, expect_hour, expect_min):
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, f"timeoffset_{label}_boot.bin")
    kernel = os.path.join(BUILDDIR, f"timeoffset_{label}_kernel.bin")
    program = os.path.join(BUILDDIR, "timeoff.com")
    img = os.path.join(BUILDDIR, f"timeoffset_{label}.img")

    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="TIMEOFF COM"',
        f"-DUTC_OFFSET_MINUTES={offset_minutes}",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        kernel,
    ])
    run_cmd([
        "nasm",
        f"-DBASE_HOUR={base_hour}",
        f"-DBASE_MIN={base_min}",
        f"-DEXPECT_HOUR={expect_hour}",
        f"-DEXPECT_MIN={expect_min}",
        "-f",
        "bin",
        "tests/programs/timeoffset.asm",
        "-o",
        program,
    ])
    run_cmd(["python3", "scripts/mkimage.py", boot, kernel, img, program])
    return img


def main():
    failed = False
    for label, offset_minutes, base_hour, base_min, expect_hour, expect_min in CASES:
        img = build_image(label, offset_minutes, base_hour, base_min, expect_hour, expect_min)
        output = run_serial_image(img, timeout=TIMEOUT)
        if not check_markers(
            output,
            required=("PASS: TIMEOFFSET", "Program exited, code=00", "HALT"),
            forbidden=("FAIL:", "EXC ", "INT 21h AH="),
            output_label=f"timeoffset {label} QEMU serial output",
        ):
            failed = True
    if failed:
        sys.exit(1)
    print("\nTime offset test passed.")


if __name__ == "__main__":
    main()
