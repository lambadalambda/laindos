#!/usr/bin/env python3
import sys
from testlib import check_markers, qemu_sb16_silent_args, run_serial_image, build_simple_test_image


def main():
    img = build_simple_test_image(
        "sbpause",
        "SBPAUSE COM",
        [("tests/programs/sbpause.asm", "sbpause.com")],
    )
    output = run_serial_image(img, timeout=10, extra_args=qemu_sb16_silent_args())
    if not check_markers(output, required=("PASS: SBPAUSE", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nSound Blaster DSP pause IRQ test passed.")


if __name__ == "__main__":
    main()
