#!/usr/bin/env python3
import os
import re
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "freetest.img")
KERNEL = os.path.join(BUILDDIR, "freetest_kernel.bin")
TIMEOUT = 10


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    free_com = os.path.join(BUILDDIR, "free.com")
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", boot])
    run([
        "nasm", '-DBOOT_FILE="FREE    COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/free.asm", "-o", free_com])
    run(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, free_com])


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def parse_number(value):
    return int(value.replace(",", ""))


def memory_row(output, label):
    match = re.search(
        rf"^{re.escape(label)}\s+([0-9,]+)\s*[kK]\s+([0-9,]+)\s*[kK]\s+([0-9,]+)\s*[kK]\r?$",
        output,
        re.MULTILINE,
    )
    if not match:
        return None
    return tuple(parse_number(group) for group in match.groups())


def ems_line(output, label):
    match = re.search(
        rf"{re.escape(label)}\s+([0-9,]+)\s+M\s+\(([0-9,]+) bytes\)",
        output,
    )
    if not match:
        return None
    return tuple(parse_number(group) for group in match.groups())


def largest_program(output):
    match = re.search(
        r"Largest executable program size\s+([0-9,]+)\s+[kK]\s+\(([0-9,]+) bytes\)",
        output,
    )
    if not match:
        return None
    return tuple(parse_number(group) for group in match.groups())


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in [
        "Memory type        Total       Used    Free",
        "Conventional",
        "Upper",
        "Reserved",
        "Extended (XMS)",
        "Total memory",
        "Total under 1 MB",
        "Total Expanded (EMS)",
        "Free Expanded (EMS)",
        "Largest executable program size",
        "Largest free upper memory block",
        "LainDOS is resident in conventional memory.",
        "Program exited, code=00",
    ]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH=", "Invalid MCB chain"]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True

    labels = [
        "Conventional",
        "Upper",
        "Reserved",
        "Extended (XMS)",
        "Total memory",
        "Total under 1 MB",
    ]
    rows = {label: memory_row(output, label) for label in labels}
    missing = [label for label, values in rows.items() if values is None]
    if missing:
        print(f"  FAIL: missing memory rows: {', '.join(missing)}")
        failed = True
    elif rows["Conventional"][0] <= 0:
        print("  FAIL: conventional memory total is zero")
        failed = True
    else:
        for label, (total_kb, used_kb, free_kb) in rows.items():
            if total_kb != used_kb + free_kb:
                print(
                    f"  FAIL: {label} mismatch "
                    f"total={total_kb}K used={used_kb}K free={free_kb}K"
                )
                failed = True
        component_labels = ["Conventional", "Upper", "Reserved", "Extended (XMS)"]
        total_expected = tuple(sum(rows[label][idx] for label in component_labels) for idx in range(3))
        under_expected = tuple(sum(rows[label][idx] for label in component_labels[:3]) for idx in range(3))
        if rows["Total memory"] != total_expected:
            print(f"  FAIL: Total memory row mismatch expected={total_expected} got={rows['Total memory']}")
            failed = True
        if rows["Total under 1 MB"] != under_expected:
            print(f"  FAIL: Total under 1 MB row mismatch expected={under_expected} got={rows['Total under 1 MB']}")
            failed = True

    ems_total = ems_line(output, "Total Expanded (EMS)")
    ems_free = ems_line(output, "Free Expanded (EMS)")
    largest = largest_program(output)
    if None in (ems_total, ems_free, largest):
        print("  FAIL: missing EMS or largest executable numbers")
        failed = True
    elif ems_free[1] > ems_total[1]:
        print(f"  FAIL: EMS free exceeds total total={ems_total[1]} free={ems_free[1]}")
        failed = True
    elif rows.get("Conventional") and largest[0] > rows["Conventional"][2]:
        print(
            "  FAIL: largest executable program exceeds conventional free memory "
            f"largest={largest[0]}K free={rows['Conventional'][2]}K"
        )
        failed = True
    elif not failed:
        print("  PASS: memory report numbers are consistent")
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFree memory report test passed.")


if __name__ == "__main__":
    main()
