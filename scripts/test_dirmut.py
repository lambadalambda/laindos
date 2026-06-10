#!/usr/bin/env python3
import os
import struct
import subprocess
import sys
from testlib import build_dir, run_qemu_capture
from fatlib import FatImage, entry_attr, entry_cluster, find_entry, iter_dir

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


def is_dot_entry(entry):
    return entry[0:11] in (b".          ", b"..         ")


def verify_dot_entries(directory, self_cluster, parent_cluster):
    dot = find_entry(directory, ".")
    dotdot = find_entry(directory, "..")
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


def collect_reachable(img, directory, clusters):
    for _, entry in iter_dir(directory):
        if is_dot_entry(entry):
            continue
        cluster = entry_cluster(entry)
        if cluster < 2:
            continue
        clusters.update(img.cluster_chain(cluster))
        if entry_attr(entry) & 0x10:
            collect_reachable(img, img.read_chain(cluster), clusters)


def verify_disk():
    img = FatImage.from_file(IMG)
    root_entries = img.root_entries
    root = img.root_dir()

    visible = find_entry(root, "VISIBLE")
    if visible is None or visible[11] & 0x10 == 0:
        print("  FAIL: VISIBLE directory missing from root")
        return False
    visible_cluster = entry_cluster(visible)
    visible_dir = img.read_chain(visible_cluster)
    if not verify_dot_entries(visible_dir, visible_cluster, 0):
        return False
    for name in ("EMPTY", "CURDIR", "NONEMPTY", "PARENT", "TOOFULL"):
        if find_entry(root, name) is not None:
            print(f"  FAIL: removed directory still active: {name!r}")
            return False

    keep = find_entry(root, "KEEP")
    if keep is None or keep[11] & 0x10 == 0:
        print("  FAIL: KEEP directory missing from root")
        return False
    keep_cluster = entry_cluster(keep)
    keep_dir = img.read_chain(keep_cluster)
    if not verify_dot_entries(keep_dir, keep_cluster, 0):
        return False
    nested = find_entry(keep_dir, "NESTED")
    if nested is None or nested[11] & 0x10 == 0:
        print("  FAIL: KEEP/NESTED directory missing")
        return False
    nested_cluster = entry_cluster(nested)
    nested_dir = img.read_chain(nested_cluster)
    if not verify_dot_entries(nested_dir, nested_cluster, keep_cluster):
        return False

    midemo = find_entry(root, "MIDEMO")
    if midemo is None or midemo[11] & 0x10 == 0:
        print("  FAIL: MIDEMO directory missing")
        return False
    midemo_dir = img.read_chain(entry_cluster(midemo))
    if find_entry(midemo_dir, "MAKEDIR") is not None:
        print("  FAIL: MIDEMO/MAKEDIR still active after RD")
        return False
    if find_entry(midemo_dir, "SUBTEST.DAT") is None:
        print("  FAIL: MIDEMO/SUBTEST.DAT missing after directory mutation")
        return False

    reachable = set()
    collect_reachable(img, root, reachable)
    active_root = sum(1 for _ in iter_dir(root))
    if active_root != root_entries:
        print(f"  FAIL: root directory was not filled: {active_root}/{root_entries} active entries")
        return False

    data_start_sector = (img.data_off - img.offset) // img.bps
    max_cluster = 2 + (img.total_sectors - data_start_sector) // img.spc
    allocated = {c for c in range(2, max_cluster) if img.fat_next(c) != 0}
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
