#!/usr/bin/env python3
import sys
from testlib import check_markers, qemu_sb16_silent_args, run_serial_image, build_simple_test_image


def main():
    img = build_simple_test_image(
        "sb16dma",
        "SB16DMA COM",
        [("tests/programs/sb16dma.asm", "sb16dma.com")],
    )
    output = run_serial_image(img, timeout=10, extra_args=qemu_sb16_silent_args())
    if not check_markers(output, required=("PASS: SB16DMA", "Program exited, code=00", "HALT")):
        sys.exit(1)
    print("\nSound Blaster 16 DMA completion test passed.")


if __name__ == "__main__":
    main()
