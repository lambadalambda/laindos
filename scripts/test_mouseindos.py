#!/usr/bin/env python3
import os
import re
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
LABELS = {
    "mouse_x": "MOUSE_X",
    "mouse_y": "MOUSE_Y",
    "mouse_buttons": "MOUSE_BUTTONS",
    "mouse_callback_mask": "MOUSE_CALLBACK_MASK",
    "mouse_callback_off": "MOUSE_CALLBACK_OFF",
    "mouse_callback_seg": "MOUSE_CALLBACK_SEG",
    "mouse_event_mask": "MOUSE_EVENT_MASK",
    "mouse_in_callback": "MOUSE_IN_CALLBACK",
    "indos_flag": "INDOS_FLAG",
    "test_mouse_invoke_callback_far": "MOUSE_INVOKE_CALLBACK_FAR",
}


def parse_listing(path):
    labels = {}
    pending = None
    with open(path, encoding="utf-8") as listing:
        for line in listing:
            if pending:
                match = re.search(r"\b([0-9A-F]{8})\b", line)
                if match:
                    labels[pending] = int(match.group(1), 16)
                    pending = None

            for label in LABELS:
                if not re.search(rf"\b{re.escape(label)}:", line):
                    continue
                match = re.search(r"\b([0-9A-F]{8})\b", line)
                if match:
                    labels[label] = int(match.group(1), 16)
                else:
                    pending = label
                break

    missing = sorted(set(LABELS) - set(labels))
    if missing:
        raise SystemExit(f"missing labels in kernel listing: {', '.join(missing)}")
    return labels


def parse_memory_constant(name):
    with open("src/memory.inc", encoding="utf-8") as memory:
        for line in memory:
            match = re.match(rf"\s*{name}\s+equ\s+(0x[0-9A-Fa-f]+|\d+)\s*$", line)
            if match:
                return int(match.group(1), 0)
    raise SystemExit(f"{name} not found in src/memory.inc")


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    kernel = os.path.join(BUILDDIR, "mouseindos_kernel.bin")
    listing = os.path.join(BUILDDIR, "mouseindos_kernel.lst")
    program = os.path.join(BUILDDIR, "mouseind.com")
    img = os.path.join(BUILDDIR, "mouseindos.img")

    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="MOUSEINDCOM"',
        "-DTEST_MOUSE_INDOS_HOOKS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        kernel,
        "-l",
        listing,
    ])

    offsets = parse_listing(listing)
    kernel_seg = parse_memory_constant("HMA_SEG")
    hma_off = parse_memory_constant("HMA_OFF")
    defines = [f"-DKERNEL_SEG=0x{kernel_seg:04X}"]
    defines += [f"-D{define}=0x{offset + hma_off:04X}" for label, define in LABELS.items()
               for offset in (offsets[label],)]
    run_cmd(["nasm", *defines, "-f", "bin", "tests/programs/mouseindos.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, kernel, img, program])

    output = run_serial_image(img)
    if not check_markers(
        output,
        required=("PASS: MOUSEINDOS", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH=", "NESTED"),
        output_label="mouseindos QEMU serial output",
    ):
        sys.exit(1)
    print("\nMouse callback InDOS test passed.")


if __name__ == "__main__":
    main()
