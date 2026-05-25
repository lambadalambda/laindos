#!/usr/bin/env python3
import os
import signal
import subprocess
import sys

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "findattr.img")
KERNEL = os.path.join(BUILDDIR, "findattr_kernel.bin")
TIMEOUT = 8


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def write_fixture(name, data):
    path = os.path.join(BUILDDIR, name)
    with open(path, "wb") as f:
        f.write(data)
    return path


def set_root_attr(image_path, dos_name, attr):
    name = dos_name.encode("ascii")
    with open(image_path, "r+b") as f:
        image = bytearray(f.read())
        bps = int.from_bytes(image[0x0B:0x0D], "little")
        reserved = int.from_bytes(image[0x0E:0x10], "little")
        fats = image[0x10]
        root_entries = int.from_bytes(image[0x11:0x13], "little")
        fat_secs = int.from_bytes(image[0x16:0x18], "little")
        root_off = (reserved + fats * fat_secs) * bps
        for off in range(root_off, root_off + root_entries * 32, 32):
            first = image[off]
            if first == 0:
                break
            if first != 0xE5 and image[off:off + 11] == name:
                image[off + 11] = attr
                f.seek(0)
                f.write(image)
                return
    print(f"Missing root entry {dos_name}", file=sys.stderr)
    sys.exit(1)


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="FINDATTRCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/findattr.asm", "-o", os.path.join(BUILDDIR, "findattr.com")])
    normal = write_fixture("normal.txt", b"normal\n")
    hidden = write_fixture("hidden.txt", b"hidden\n")
    system = write_fixture("system.txt", b"system\n")
    volume = write_fixture("volume.lbl", b"label\n")
    subfile = write_fixture("subfile.dat", b"subdir\n")
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "findattr.com"),
        normal,
        hidden,
        system,
        volume,
        f"SUBDIR:{subfile}",
    ])
    set_root_attr(IMG, "HIDDEN  TXT", 0x22)
    set_root_attr(IMG, "SYSTEM  TXT", 0x24)
    set_root_attr(IMG, "VOLUME  LBL", 0x08)


def run_qemu():
    proc = subprocess.Popen(
        [
            QEMU,
            "-drive", f"file={IMG},format=raw,if=floppy",
            "-boot", "order=a",
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


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: FINDATTR", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nFind attribute test passed.")


if __name__ == "__main__":
    main()
