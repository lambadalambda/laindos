#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, run_cmd, run_serial_image

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
TIMEOUT = 8
CASES = [
    ("sec_per_clus", "TEST_BAD_BPB_SEC_PER_CLUS"),
    ("root_entries", "TEST_BAD_BPB_ROOT_ENTRIES"),
    ("fat_secs", "TEST_BAD_BPB_FAT_SECS"),
]


def build_image(name, define):
    img = os.path.join(BUILDDIR, f"bpb_invalid_{name}.img")
    kernel = os.path.join(BUILDDIR, f"bpb_invalid_{name}_kernel.bin")
    boot = os.path.join(BUILDDIR, "boot.bin")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", f"-D{define}", "-f", "bin", "src/kernel.asm", "-o", kernel])
    run_cmd(["python3", "scripts/mkimage.py", boot, kernel, img])
    return img


def run_case(name, define):
    img = build_image(name, define)
    output = run_serial_image(img, TIMEOUT)
    failed = False
    for marker in ["LainDOS booted", "Invalid BPB", "HALT"]:
        if marker in output:
            print(f"  PASS: [{name}] found '{marker}'")
        else:
            print(f"  FAIL: [{name}] missing '{marker}'")
            failed = True
    for marker in ["EXC ", "Program exited, code="]:
        if marker in output:
            print(f"  FAIL: [{name}] unexpected '{marker}'")
            failed = True
    if failed:
        print(f"\n--- QEMU serial output ({name}) ---")
        print(output)
        print("--- end ---")
    return not failed


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    ok = True
    for name, define in CASES:
        ok = run_case(name, define) and ok
    if not ok:
        sys.exit(1)
    print("\nInvalid BPB boot test passed.")


if __name__ == "__main__":
    main()
