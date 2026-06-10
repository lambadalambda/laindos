#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
from testlib import run_serial_image, run_cmd, build_dir, run_qemu_capture
from fatlib import FatImage, entry_cluster, entry_size, find_entry, find_entry_offset

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "savewrite.img")
KERNEL = os.path.join(BUILDDIR, "savewrite_kernel.bin")
TIMEOUT = 8
FILLER_COUNT = 29


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run_cmd([
        "nasm", '-DBOOT_FILE="SAVEWR  COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/savewr.asm", "-o", os.path.join(BUILDDIR, "savewr.com")])
    run_cmd(["python3", "scripts/mksubtest.py", os.path.join(BUILDDIR, "subtest.dat")])
    filler_files = []
    for i in range(FILLER_COUNT):
        path = os.path.join(BUILDDIR, f"fill{i:02d}.dat")
        with open(path, "wb") as f:
            f.write(f"filler {i:02d}\n".encode("ascii"))
        filler_files.append(path)
    run_cmd([
        "python3", "scripts/mkimage.py",
        "--format=2880k",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "savewr.com"),
        *[f"MIDEMO:{path}" for path in filler_files],
        f"MIDEMO:{os.path.join(BUILDDIR, 'subtest.dat')}",
    ])


def run_qemu():
    return run_serial_image(IMG, TIMEOUT)


def verify_disk_file():
    img = FatImage.from_file(IMG)
    bps = img.bps
    spc = img.spc
    root = img.root_dir()
    if spc != 2:
        print(f"  FAIL: expected sec_per_clus=2 for multi-sector directory test, got {spc}")
        return False
    deleted_seen = find_entry(root, "SAVEDONE.DAT") is not None
    entry = find_entry(root, "REUSED.DAT")
    readonly_entry = find_entry(root, "READONLY.DAT")
    readonly_seen = readonly_entry is not None and readonly_entry[11] & 0x01
    if deleted_seen:
        print("  FAIL: SAVEDONE.DAT still present after delete")
        return False
    if entry is None:
        print("  FAIL: REUSED.DAT missing from disk image")
        return False
    if not readonly_seen:
        print("  FAIL: READONLY.DAT was deleted or lost its read-only attribute")
        return False
    cluster = entry_cluster(entry)
    size = entry_size(entry)
    time_word = struct.unpack_from("<H", entry, 22)[0]
    date_word = struct.unpack_from("<H", entry, 24)[0]
    if size != 700:
        print(f"  FAIL: bad entry size/date: size={size} time={time_word:04X} date={date_word:04X}")
        return False
    data = img.read_chain(cluster)
    expected = bytes([i & 0xFF for i in range(700)])
    if data[:700] != expected:
        print("  FAIL: disk file contents mismatch")
        return False
    print("  PASS: disk image contains REUSED.DAT contents after delete")

    if find_entry(root, "STALE.DAT") is not None:
        print("  FAIL: STALE.DAT still present after delete")
        return False
    gap_entry = find_entry(root, "GAP.DAT")
    if gap_entry is None:
        print("  FAIL: GAP.DAT missing from disk image")
        return False
    gap_cluster = entry_cluster(gap_entry)
    gap_size = entry_size(gap_entry)
    gap_data = img.read_chain(gap_cluster)
    if gap_size != 601 or gap_data[:1] != b"A" or gap_data[1:600] != bytes(599) or gap_data[600:601] != b"Z":
        print("  FAIL: GAP.DAT sparse write gap was not zero-filled")
        return False

    midemo = find_entry(root, "MIDEMO")
    if midemo is None:
        print("  FAIL: MIDEMO directory missing")
        return False
    midemo_dir = img.read_chain(entry_cluster(midemo))
    subtest_off = find_entry_offset(midemo_dir, "SUBTEST.DAT")
    if subtest_off is not None and subtest_off < bps:
        print("  FAIL: MIDEMO/SUBTEST.DAT was not placed in the second directory sector")
        return False
    subtest_entry = None if subtest_off is None else midemo_dir[subtest_off:subtest_off + 32]
    if subtest_entry is None:
        print("  FAIL: MIDEMO/SUBTEST.DAT missing after subdirectory operations")
        return False
    subtest_cluster = entry_cluster(subtest_entry)
    subtest_size = entry_size(subtest_entry)
    subtest_data = img.read_chain(subtest_cluster)
    expected_subtest = b"Hello from MIDEMO subdirectory!\n"
    if subtest_size != len(expected_subtest) or subtest_data[:subtest_size] != expected_subtest:
        print("  FAIL: MIDEMO/SUBTEST.DAT contents changed")
        return False
    if find_entry(midemo_dir, "SUBSAVE.DAT") is not None:
        print("  FAIL: MIDEMO/SUBSAVE.DAT still present after rename")
        return False
    if find_entry(midemo_dir, "SUBDONE.DAT") is not None:
        print("  FAIL: MIDEMO/SUBDONE.DAT still present after delete")
        return False
    if find_entry(midemo_dir, "PATHSAVE.DAT") is not None:
        print("  FAIL: MIDEMO/PATHSAVE.DAT still present after rename")
        return False
    if find_entry(midemo_dir, "PATHDONE.DAT") is not None:
        print("  FAIL: MIDEMO/PATHDONE.DAT still present after delete")
        return False
    sub_entry_off = find_entry_offset(midemo_dir, "SUBUSED.DAT")
    if sub_entry_off is not None and sub_entry_off < bps * spc:
        print("  FAIL: MIDEMO/SUBUSED.DAT was not created in an extended directory cluster")
        return False
    sub_entry = None if sub_entry_off is None else midemo_dir[sub_entry_off:sub_entry_off + 32]
    if sub_entry is None:
        print("  FAIL: MIDEMO/SUBUSED.DAT missing")
        return False
    sub_cluster = entry_cluster(sub_entry)
    sub_size = entry_size(sub_entry)
    if sub_size != 700:
        print(f"  FAIL: bad MIDEMO/SUBUSED.DAT size: {sub_size}")
        return False
    sub_data = img.read_chain(sub_cluster)
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
