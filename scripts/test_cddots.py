#!/usr/bin/env python3
import os
import sys
from testlib import build_dir, check_markers, run_cmd, run_qemu_capture

BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cddots")
TIMEOUT = 15


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    boot = os.path.join(WORKDIR, "boot.bin")
    kernel = os.path.join(WORKDIR, "kernel.bin")
    program = os.path.join(WORKDIR, "cddots.com")
    iso = os.path.join(WORKDIR, "cddots.iso")
    img = os.path.join(WORKDIR, "cddots.img")
    sibl = os.path.join(WORKDIR, "sibl.txt")
    deep = os.path.join(WORKDIR, "deep.txt")
    last = os.path.join(WORKDIR, "last.txt")
    tiny = os.path.join(WORKDIR, "tiny.txt")
    with open(sibl, "wb") as f:
        f.write(b"sibl\r\n")
    with open(deep, "wb") as f:
        f.write(b"deep\r\n")
    with open(last, "wb") as f:
        f.write(b"last\r\n")
    with open(tiny, "wb") as f:
        f.write(b"x")
    members = [f"D1/SIBL.TXT={sibl}", f"D1/D2/DEEP.TXT={deep}",
               f"BIG/LAST.TXT={last}"]
    members += [f"BIG/F{i:04d}.TXT={tiny}" for i in range(1500)]
    run_cmd(["python3", "scripts/mkiso.py", iso, *members])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="CDDOTS  COM"', "-f", "bin", "src/kernel.asm",
             "-o", kernel])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cddots.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, kernel, img, program])
    return img, iso


def main():
    img, iso = build_artifacts()
    output, timed_out = run_qemu_capture([
        "qemu-system-i386",
        "-drive", f"file={img},format=raw,if=floppy",
        "-drive", f"file={iso},format=raw,if=ide,media=cdrom,readonly=on",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    ok = check_markers(
        output,
        required=("PASS: CDDOTS PARENT", "PASS: CDDOTS BIGDIR",
                  "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="cddots QEMU serial output")
    if not ok or timed_out:
        if timed_out:
            print("  FAIL: QEMU run timed out")
        sys.exit(1)
    print("\nCD parent-dir and large-directory test passed.")


if __name__ == "__main__":
    main()
