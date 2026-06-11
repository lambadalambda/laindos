#!/usr/bin/env python3
"""LOADFIX places its child above the first 64 KiB.

EXEPACK-compressed era executables (Civilization's CIV.EXE among them)
corrupt themselves when loaded below segment 1000h, which is exactly
where a lean DOS-in-HMA layout puts the first program. Real MS-DOS 5
shipped LOADFIX.COM for this; this test pins the LainDOS LOADFIX:
a bare child reports a PSP below 1000h, a LOADFIX'd child reports one
at or above it with its command tail intact, and the error paths set
a nonzero exit code.
"""
import os
import re
import sys
from testlib import build_dir, check_markers, run_cmd, run_serial_image

BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "loadfix.img")
KERNEL = os.path.join(BUILDDIR, "loadfix_kernel.bin")
TIMEOUT = 15


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    boot = os.path.join(BUILDDIR, "boot.bin")
    shell = os.path.join(BUILDDIR, "shell.com")
    loadfix = os.path.join(BUILDDIR, "loadfix.com")
    pspseg = os.path.join(BUILDDIR, "pspseg.com")
    autoexec = os.path.join(BUILDDIR, "autoexec_loadfix.bat")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", shell])
    run_cmd(["nasm", "-f", "bin", "programs/loadfix.asm", "-o", loadfix])
    run_cmd(["nasm", "-f", "bin", "tests/programs/pspseg.asm", "-o", pspseg])
    with open(autoexec, "wb") as f:
        f.write(b"echo off\r\n"
                b"pspseg\r\n"
                b"loadfix pspseg hello tail\r\n"
                b"if errorlevel 1 echo CODE1BAD\r\n"
                b"loadfix nosuch\r\n"
                b"if errorlevel 1 echo CODE2OK\r\n"
                b"loadfix\r\n"
                b"if errorlevel 1 echo CODE3OK\r\n"
                b"echo LOADFIXDONE\r\n"
                b"exit\r\n")
    run_cmd(["python3", "scripts/mkimage.py", boot, KERNEL, IMG, shell, loadfix, pspseg, autoexec])


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT)
    required = (
        "PSPTAIL= hello tail<",
        "LOADFIX: cannot run program",
        "Usage: LOADFIX program [args]",
        "CODE2OK",
        "CODE3OK",
        "LOADFIXDONE",
        "HALT",
    )
    forbidden = ("CODE1BAD",)
    failed = not check_markers(output, required=required, forbidden=forbidden)

    segs = [int(m, 16) for m in re.findall(r"PSPSEG=([0-9A-F]{4})", output)]
    if len(segs) != 2:
        print(f"  FAIL: expected 2 PSPSEG reports, got {segs}")
        failed = True
    else:
        bare, fixed = segs
        if bare >= 0x1000:
            print(f"  FAIL: bare child already at {bare:04X}; test layout assumption broken")
            failed = True
        else:
            print(f"  PASS: bare child below 64K ({bare:04X})")
        if fixed < 0x1000:
            print(f"  FAIL: LOADFIX child still below 64K ({fixed:04X})")
            failed = True
        else:
            print(f"  PASS: LOADFIX child at or above 64K ({fixed:04X})")
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        sys.exit(1)
    print("LOADFIX test passed.")


if __name__ == "__main__":
    main()
