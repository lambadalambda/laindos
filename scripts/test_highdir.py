#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "highdir.img")
KERNEL = os.path.join(BUILDDIR, "highdir_kernel.bin")
TIMEOUT = 20
SEED = b"seed-high-dir"
OUT = b"high-lba-dir-write"
HIGH_LBA_MIN = 0x10000


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
    boot = os.path.join(BUILDDIR, "highdir_boot.bin")
    highdir = os.path.join(BUILDDIR, "highdir.com")
    filler = os.path.join(BUILDDIR, "highdir_fill.dat")
    seed = os.path.join(BUILDDIR, "seed.dat")
    run(["nasm", "-f", "bin", "src/boot16.asm", "-o", boot])
    run(["nasm", '-DBOOT_FILE="HIGHDIR COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run(["nasm", "-f", "bin", "tests/programs/highdir.asm", "-o", highdir])
    with open(filler, "wb") as f:
        f.truncate(34 * 1024 * 1024)
    with open(seed, "wb") as f:
        f.write(SEED)
    run(["python3", "scripts/mkimage.py", "--format=hd96m", boot, KERNEL, IMG, highdir, filler, f"HIDIR:{seed}"])


def run_qemu():
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={IMG},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT)
    return output


def fat16_get(fat, cluster):
    return struct.unpack_from("<H", fat, cluster * 2)[0]


def cluster_chain(fat, cluster):
    chain = []
    seen = set()
    while 2 <= cluster < 0xFFF8:
        if cluster in seen:
            raise RuntimeError(f"cluster loop at {cluster}")
        seen.add(cluster)
        chain.append(cluster)
        cluster = fat16_get(fat, cluster)
    return chain


def read_chain(image, fat, data_start, bps, spc, cluster):
    data = bytearray()
    for c in cluster_chain(fat, cluster):
        off = (data_start + (c - 2) * spc) * bps
        data.extend(image[off:off + spc * bps])
    return bytes(data)


def iter_entries(directory):
    for off in range(0, len(directory), 32):
        entry = directory[off:off + 32]
        if entry[0] == 0:
            break
        if entry[0] != 0xE5:
            yield entry


def find_entry(directory, name):
    for entry in iter_entries(directory):
        if entry[0:11] == name:
            return entry
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

    hidir = find_entry(root, b"HIDIR      ")
    if hidir is None or hidir[11] & 0x10 == 0:
        print("  FAIL: HIDIR missing from root")
        return False
    hidir_cluster = struct.unpack_from("<H", hidir, 26)[0]
    hidir_lba = data_start + (hidir_cluster - 2) * spc
    if hidir_lba < HIGH_LBA_MIN:
        print(f"  FAIL: HIDIR LBA is not high: {hidir_lba}")
        return False
    directory = read_chain(image, fat, data_start, bps, spc, hidir_cluster)
    renamed = find_entry(directory, b"RENAMED DAT")
    if renamed is None:
        print("  FAIL: RENAMED.DAT missing from high directory")
        return False
    if renamed[11] != 0x02:
        print("  FAIL: RENAMED.DAT attribute change was not flushed")
        return False
    if struct.unpack_from("<I", renamed, 28)[0] != len(OUT):
        print("  FAIL: RENAMED.DAT size was not flushed")
        return False
    if find_entry(directory, b"SUBTEMP    ") is not None:
        print("  FAIL: SUBTEMP directory still active after rmdir")
        return False
    if find_entry(directory, b"DELME   DAT") is not None:
        print("  FAIL: DELME.DAT still active after delete")
        return False
    out_cluster = struct.unpack_from("<H", renamed, 26)[0]
    if out_cluster < 2:
        print("  FAIL: RENAMED.DAT cluster was not flushed")
        return False
    data = read_chain(image, fat, data_start, bps, spc, out_cluster)[:len(OUT)]
    if data != OUT:
        print("  FAIL: RENAMED.DAT contents mismatch")
        return False
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in [
        "MiniDOS booted",
        "PASS: HIGHDIR",
        "Program exited, code=00",
        "HALT",
    ]:
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
    print("\nHigh-LBA FAT16 directory test passed.")


if __name__ == "__main__":
    main()
