#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
from testlib import build_dir, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "dirmut.img")
KERNEL = os.path.join(BUILDDIR, "dirmut_kernel.bin")
TIMEOUT = 15
FILLER_COUNT = 29


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
    run(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", os.path.join(BUILDDIR, "boot.bin")])
    run([
        "nasm", '-DBOOT_FILE="DIRMUT  COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run(["nasm", "-f", "bin", "tests/programs/dirmut.asm", "-o", os.path.join(BUILDDIR, "dirmut.com")])
    run(["python3", "scripts/mksubtest.py", os.path.join(BUILDDIR, "subtest.dat")])
    filler_files = []
    for i in range(FILLER_COUNT):
        path = os.path.join(BUILDDIR, f"dirfill{i:02d}.dat")
        with open(path, "wb") as f:
            f.write(f"dir filler {i:02d}\n".encode("ascii"))
        filler_files.append(path)
    run([
        "python3", "scripts/mkimage.py",
        "--format=2880k",
        os.path.join(BUILDDIR, "boot.bin"),
        KERNEL,
        IMG,
        os.path.join(BUILDDIR, "dirmut.com"),
        *[f"MIDEMO:{path}" for path in filler_files],
        f"MIDEMO:{os.path.join(BUILDDIR, 'subtest.dat')}",
    ])


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


def read_cluster_chain(image, fat, data_start, bps, spc, cluster):
    data = bytearray()
    for c in cluster_chain(fat, cluster):
        off = (data_start + (c - 2) * spc) * bps
        data.extend(image[off:off + spc * bps])
    return bytes(data)


def iter_entries(directory):
    for off in range(0, len(directory), 32):
        first = directory[off]
        if first == 0:
            break
        if first != 0xE5:
            yield directory[off:off + 32]


def find_entry(directory, name):
    for entry in iter_entries(directory):
        if entry[0:11] == name:
            return entry
    return None


def is_dot_entry(entry):
    return entry[0:11] in (b".          ", b"..         ")


def verify_dot_entries(directory, self_cluster, parent_cluster):
    dot = find_entry(directory, b".          ")
    dotdot = find_entry(directory, b"..         ")
    if dot is None or dotdot is None:
        print("  FAIL: directory missing . or .. entry")
        return False
    if dot[11] & 0x10 == 0 or dotdot[11] & 0x10 == 0:
        print("  FAIL: . or .. entry is not marked as directory")
        return False
    if struct.unpack_from("<H", dot, 26)[0] != self_cluster:
        print("  FAIL: . entry points at wrong cluster")
        return False
    if struct.unpack_from("<H", dotdot, 26)[0] != parent_cluster:
        print("  FAIL: .. entry points at wrong cluster")
        return False
    return True


def collect_reachable(image, fat, data_start, bps, spc, directory, clusters):
    for entry in iter_entries(directory):
        if is_dot_entry(entry):
            continue
        cluster = struct.unpack_from("<H", entry, 26)[0]
        if cluster < 2:
            continue
        chain = cluster_chain(fat, cluster)
        clusters.update(chain)
        if entry[11] & 0x10:
            data = read_cluster_chain(image, fat, data_start, bps, spc, cluster)
            collect_reachable(image, fat, data_start, bps, spc, data, clusters)


def verify_disk():
    with open(IMG, "rb") as f:
        image = f.read()
    bps = struct.unpack_from("<H", image, 0x0B)[0]
    spc = image[0x0D]
    reserved = struct.unpack_from("<H", image, 0x0E)[0]
    fats = image[0x10]
    root_entries = struct.unpack_from("<H", image, 0x11)[0]
    fat_secs = struct.unpack_from("<H", image, 0x16)[0]
    total = struct.unpack_from("<H", image, 0x13)[0]
    root_start = reserved + fats * fat_secs
    root_secs = (root_entries * 32 + bps - 1) // bps
    data_start = root_start + root_secs
    fat = image[reserved * bps:(reserved + fat_secs) * bps]
    root = image[root_start * bps:(root_start + root_secs) * bps]

    visible = find_entry(root, b"VISIBLE    ")
    if visible is None or visible[11] & 0x10 == 0:
        print("  FAIL: VISIBLE directory missing from root")
        return False
    visible_cluster = struct.unpack_from("<H", visible, 26)[0]
    visible_dir = read_cluster_chain(image, fat, data_start, bps, spc, visible_cluster)
    if not verify_dot_entries(visible_dir, visible_cluster, 0):
        return False
    for name in (b"EMPTY      ", b"CURDIR     ", b"NONEMPTY   ", b"PARENT     ", b"TOOFULL    "):
        if find_entry(root, name) is not None:
            print(f"  FAIL: removed directory still active: {name!r}")
            return False

    keep = find_entry(root, b"KEEP       ")
    if keep is None or keep[11] & 0x10 == 0:
        print("  FAIL: KEEP directory missing from root")
        return False
    keep_cluster = struct.unpack_from("<H", keep, 26)[0]
    keep_dir = read_cluster_chain(image, fat, data_start, bps, spc, keep_cluster)
    if not verify_dot_entries(keep_dir, keep_cluster, 0):
        return False
    nested = find_entry(keep_dir, b"NESTED     ")
    if nested is None or nested[11] & 0x10 == 0:
        print("  FAIL: KEEP/NESTED directory missing")
        return False
    nested_cluster = struct.unpack_from("<H", nested, 26)[0]
    nested_dir = read_cluster_chain(image, fat, data_start, bps, spc, nested_cluster)
    if not verify_dot_entries(nested_dir, nested_cluster, keep_cluster):
        return False

    midemo = find_entry(root, b"MIDEMO     ")
    if midemo is None or midemo[11] & 0x10 == 0:
        print("  FAIL: MIDEMO directory missing")
        return False
    midemo_cluster = struct.unpack_from("<H", midemo, 26)[0]
    midemo_dir = read_cluster_chain(image, fat, data_start, bps, spc, midemo_cluster)
    if find_entry(midemo_dir, b"MAKEDIR    ") is not None:
        print("  FAIL: MIDEMO/MAKEDIR still active after RD")
        return False
    if find_entry(midemo_dir, b"SUBTEST DAT") is None:
        print("  FAIL: MIDEMO/SUBTEST.DAT missing after directory mutation")
        return False

    reachable = set()
    collect_reachable(image, fat, data_start, bps, spc, root, reachable)
    active_root = sum(1 for _ in iter_entries(root))
    if active_root != root_entries:
        print(f"  FAIL: root directory was not filled: {active_root}/{root_entries} active entries")
        return False

    max_cluster = 2 + (total - data_start) // spc
    allocated = {c for c in range(2, max_cluster) if get_fat12(fat, c) != 0}
    leaked = allocated - reachable
    if leaked:
        print(f"  FAIL: allocated clusters are unreachable: {sorted(leaked)[:8]}")
        return False
    print("  PASS: directory entries and FAT reachability verified")
    return True


def main():
    build_image()
    output = run_qemu()
    failed = False
    for marker in ["PASS: DIRMUT", "Program exited, code=00"]:
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
    print("\nDirectory mutation test passed.")


if __name__ == "__main__":
    main()
