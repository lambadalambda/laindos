#!/usr/bin/env python3
import os
import signal
import struct
import subprocess
import sys

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "termflush.img")
KERNEL = os.path.join(BUILDDIR, "termflush_kernel.bin")
TIMEOUT = 8
PAYLOAD = b"termination flush payload\r\n"


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
    run(["nasm", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="TERMFLUSCOM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/termflush.asm", "-o", os.path.join(BUILDDIR, "termflus.com")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "termflus.com"),
    ])


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


def get_fat12(fat, cluster):
    off = cluster + (cluster >> 1)
    if cluster & 1:
        return ((fat[off] >> 4) | (fat[off + 1] << 4)) & 0xFFF
    return (fat[off] | ((fat[off + 1] & 0x0F) << 8)) & 0xFFF


def cluster_chain(fat, cluster):
    chain = []
    seen = set()
    while 2 <= cluster < 0xFF8:
        if cluster in seen:
            raise RuntimeError(f"cluster loop at {cluster}")
        seen.add(cluster)
        chain.append(cluster)
        cluster = get_fat12(fat, cluster)
    return chain


def find_root_entry(root, name):
    for off in range(0, len(root), 32):
        first = root[off]
        if first == 0:
            break
        if first != 0xE5 and root[off:off + 11] == name:
            return root[off:off + 32]
    return None


def verify_disk():
    with open(IMG, "rb") as f:
        image = f.read()
    bps = struct.unpack_from("<H", image, 0x0B)[0]
    spc = image[0x0D]
    reserved = struct.unpack_from("<H", image, 0x0E)[0]
    fats = image[0x10]
    root_entries = struct.unpack_from("<H", image, 0x11)[0]
    fat_secs = struct.unpack_from("<H", image, 0x16)[0]
    root_start = reserved + fats * fat_secs
    root_secs = (root_entries * 32 + bps - 1) // bps
    data_start = root_start + root_secs
    fat = image[reserved * bps:(reserved + fat_secs) * bps]
    root = image[root_start * bps:(root_start + root_secs) * bps]
    entry = find_root_entry(root, b"TERMOUT DAT")
    if entry is None:
        print("  FAIL: TERMOUT.DAT missing")
        return False
    cluster = struct.unpack_from("<H", entry, 26)[0]
    size = struct.unpack_from("<I", entry, 28)[0]
    if size != len(PAYLOAD):
        print(f"  FAIL: TERMOUT.DAT size {size}, expected {len(PAYLOAD)}")
        return False
    if cluster < 2:
        print(f"  FAIL: TERMOUT.DAT invalid start cluster {cluster}")
        return False
    data = bytearray()
    for c in cluster_chain(fat, cluster):
        off = (data_start + (c - 2) * spc) * bps
        data.extend(image[off:off + spc * bps])
    if bytes(data[:len(PAYLOAD)]) != PAYLOAD:
        print("  FAIL: TERMOUT.DAT payload mismatch")
        return False
    print("  PASS: termination flushed written handle")
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: TERMFLUSH", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if not verify_disk():
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nTermination flush test passed.")


if __name__ == "__main__":
    main()
