#!/usr/bin/env python3
import os
import signal
import subprocess
import sys

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
HD_IMG = os.path.join(BUILDDIR, "drivetest_hd.img")
FLOPPY_IMG = os.path.join(BUILDDIR, "drivetest_floppy.img")
KERNEL = os.path.join(BUILDDIR, "drivetest_kernel.bin")
BOOT = os.path.join(BUILDDIR, "boot.bin")
DRIVE_COM = os.path.join(BUILDDIR, "drive.com")
TIMEOUT = 10


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def build_artifacts():
    os.makedirs(BUILDDIR, exist_ok=True)
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run([
        "nasm", '-DBOOT_FILE="DRIVE   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/drivetest.asm", "-o", DRIVE_COM])


def build_image(output_path, fmt=None):
    cmd = ["python3", "scripts/mkimage.py"]
    if fmt:
        cmd.append(f"--format={fmt}")
    cmd.extend([BOOT, KERNEL, output_path, DRIVE_COM])
    run(cmd)


def run_qemu(image_path, hard_disk):
    drive_arg = f"file={image_path},format=raw"
    if not hard_disk:
        drive_arg += ",if=floppy"
    boot_order = "c" if hard_disk else "a"
    proc = subprocess.Popen(
        [
            QEMU,
            "-drive", drive_arg,
            "-boot", f"order={boot_order}",
            "-serial", "stdio",
            "-monitor", "none",
            "-nographic",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        stdout, stderr = proc.communicate(timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        proc.send_signal(signal.SIGTERM)
        try:
            stdout, stderr = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            stdout, stderr = proc.communicate()

    output = stdout.decode("utf-8", errors="replace")
    err = stderr.decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def check_output(label, output):
    failed = False
    for marker in ["PASS: DRIVE", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: {label} found '{marker}'")
        else:
            print(f"  FAIL: {label} missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: {label} unexpected '{marker}'")
            failed = True
    if failed:
        print(f"\n--- QEMU serial output ({label}) ---")
        print(output)
        print("--- end ---")
    return failed


def main():
    build_artifacts()
    build_image(HD_IMG, "hd10m")
    build_image(FLOPPY_IMG)
    failed = check_output("hard disk", run_qemu(HD_IMG, True))
    failed |= check_output("floppy", run_qemu(FLOPPY_IMG, False))
    if failed:
        sys.exit(1)
    print("\nDrive API test passed.")


if __name__ == "__main__":
    main()
