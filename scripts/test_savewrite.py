#!/usr/bin/env python3
import os
import signal
import struct
import subprocess
import sys

QEMU = "qemu-system-i386"
BUILDDIR = os.path.join(os.path.dirname(__file__), "..", "build")
IMG = os.path.join(BUILDDIR, "savewrite.img")
KERNEL = os.path.join(BUILDDIR, "savewrite_kernel.bin")
TIMEOUT = 8


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
        "nasm", '-DBOOT_FILE="SAVEWR  COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "src/savewr.asm", "-o", os.path.join(BUILDDIR, "savewr.com")])
    run(["python3", "scripts/mksubtest.py", os.path.join(BUILDDIR, "subtest.dat")])
    run([
        "python3", "scripts/mkimage.py",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "savewr.com"),
        f"MIDEMO:{os.path.join(BUILDDIR, 'subtest.dat')}",
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


def read_cluster_chain(image, fat, data_start, bps, spc, cluster):
    data = bytearray()
    while 2 <= cluster < 0xFF8:
        off = (data_start + (cluster - 2) * spc) * bps
        data.extend(image[off:off + spc * bps])
        cluster = get_fat12(fat, cluster)
    return bytes(data)


def find_entry(directory, name):
    for off in range(0, len(directory), 32):
        first = directory[off]
        if first == 0:
            break
        if first != 0xE5 and directory[off:off + 11] == name:
            return directory[off:off + 32]
    return None


def verify_disk_file():
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
    deleted = b"SAVEDONE" + b"DAT"
    target = b"REUSED  " + b"DAT"
    readonly = b"READONLY" + b"DAT"
    entry = None
    deleted_seen = False
    readonly_seen = False
    for off in range(0, len(root), 32):
        first = root[off]
        if first == 0:
            break
        if first != 0xE5 and root[off:off + 11] == deleted:
            deleted_seen = True
        if first != 0xE5 and root[off:off + 11] == target:
            entry = root[off:off + 32]
        if first != 0xE5 and root[off:off + 11] == readonly and root[off + 11] & 0x01:
            readonly_seen = True
    if deleted_seen:
        print("  FAIL: SAVEDONE.DAT still present after delete")
        return False
    if entry is None:
        print("  FAIL: REUSED.DAT missing from disk image")
        return False
    if not readonly_seen:
        print("  FAIL: READONLY.DAT was deleted or lost its read-only attribute")
        return False
    cluster = struct.unpack_from("<H", entry, 26)[0]
    size = struct.unpack_from("<I", entry, 28)[0]
    time_word = struct.unpack_from("<H", entry, 22)[0]
    date_word = struct.unpack_from("<H", entry, 24)[0]
    if size != 700:
        print(f"  FAIL: bad entry size/date: size={size} time={time_word:04X} date={date_word:04X}")
        return False
    data = read_cluster_chain(image, fat, data_start, bps, spc, cluster)
    expected = bytes([i & 0xFF for i in range(700)])
    if data[:700] != expected:
        print("  FAIL: disk file contents mismatch")
        return False
    print("  PASS: disk image contains REUSED.DAT contents after delete")

    midemo = find_entry(root, b"MIDEMO  " + b"   ")
    if midemo is None:
        print("  FAIL: MIDEMO directory missing")
        return False
    midemo_cluster = struct.unpack_from("<H", midemo, 26)[0]
    midemo_dir = read_cluster_chain(image, fat, data_start, bps, spc, midemo_cluster)
    subtest_entry = find_entry(midemo_dir, b"SUBTEST " + b"DAT")
    if subtest_entry is None:
        print("  FAIL: MIDEMO/SUBTEST.DAT missing after subdirectory operations")
        return False
    subtest_cluster = struct.unpack_from("<H", subtest_entry, 26)[0]
    subtest_size = struct.unpack_from("<I", subtest_entry, 28)[0]
    subtest_data = read_cluster_chain(image, fat, data_start, bps, spc, subtest_cluster)
    expected_subtest = b"Hello from MIDEMO subdirectory!\n"
    if subtest_size != len(expected_subtest) or subtest_data[:subtest_size] != expected_subtest:
        print("  FAIL: MIDEMO/SUBTEST.DAT contents changed")
        return False
    if find_entry(midemo_dir, b"SUBSAVE " + b"DAT") is not None:
        print("  FAIL: MIDEMO/SUBSAVE.DAT still present after rename")
        return False
    if find_entry(midemo_dir, b"SUBDONE " + b"DAT") is not None:
        print("  FAIL: MIDEMO/SUBDONE.DAT still present after delete")
        return False
    sub_entry = find_entry(midemo_dir, b"SUBUSED " + b"DAT")
    if sub_entry is None:
        print("  FAIL: MIDEMO/SUBUSED.DAT missing")
        return False
    sub_cluster = struct.unpack_from("<H", sub_entry, 26)[0]
    sub_size = struct.unpack_from("<I", sub_entry, 28)[0]
    if sub_size != 700:
        print(f"  FAIL: bad MIDEMO/SUBUSED.DAT size: {sub_size}")
        return False
    sub_data = read_cluster_chain(image, fat, data_start, bps, spc, sub_cluster)
    if sub_data[:700] != expected:
        print("  FAIL: MIDEMO/SUBUSED.DAT contents mismatch")
        return False
    print("  PASS: disk image contains MIDEMO/SUBUSED.DAT contents after delete")
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: SAVEWRITE", "Program exited, code=00"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if not verify_disk_file():
        failed = True
    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nSave write test passed.")


if __name__ == "__main__":
    main()
