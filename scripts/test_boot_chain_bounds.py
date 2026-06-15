#!/usr/bin/env python3
import os
import shutil
import struct
import sys
from testlib import build_dir, run_cmd, run_qemu_capture

QEMU = "qemu-system-i386"
BUILDDIR = build_dir()
TIMEOUT = 8


def set_fat12(fat, cluster, value):
    off = cluster + (cluster >> 1)
    if cluster & 1:
        fat[off] = (fat[off] & 0x0F) | ((value & 0x0F) << 4)
        fat[off + 1] = (value >> 4) & 0xFF
    else:
        fat[off] = value & 0xFF
        fat[off + 1] = (fat[off + 1] & 0xF0) | ((value >> 8) & 0x0F)


def set_fat16(fat, cluster, value):
    struct.pack_into("<H", fat, cluster * 2, value)


def bpb_layout(image):
    bps = struct.unpack_from("<H", image, 0x0B)[0]
    spc = image[0x0D]
    reserved = struct.unpack_from("<H", image, 0x0E)[0]
    fats = image[0x10]
    root_entries = struct.unpack_from("<H", image, 0x11)[0]
    total = struct.unpack_from("<H", image, 0x13)[0]
    if total == 0:
        total = struct.unpack_from("<I", image, 0x20)[0]
    fat_secs = struct.unpack_from("<H", image, 0x16)[0]
    root_secs = (root_entries * 32 + bps - 1) // bps
    data_start = reserved + fats * fat_secs + root_secs
    max_cluster = (total - data_start) // spc + 2
    return {
        "bps": bps,
        "spc": spc,
        "reserved": reserved,
        "fats": fats,
        "root_entries": root_entries,
        "fat_secs": fat_secs,
        "root_secs": root_secs,
        "data_start": data_start,
        "max_cluster": max_cluster,
    }


def bpb_geometry(image):
    layout = bpb_layout(image)
    bps = layout["bps"]
    spc = layout["spc"]
    reserved = layout["reserved"]
    fats = layout["fats"]
    fat_secs = layout["fat_secs"]
    max_cluster = layout["max_cluster"]
    return bps, spc, reserved, fats, fat_secs, max_cluster


def corrupt_kernel_next(img_path, fat_bits, value):
    with open(img_path, "r+b") as f:
        image = bytearray(f.read())
        bps, _spc, reserved, fats, fat_secs, _max_cluster = bpb_geometry(image)
        fat = bytearray(image[reserved * bps:(reserved + fat_secs) * bps])
        if fat_bits == 12:
            first = 2
            set_fat12(fat, first, value)
        else:
            first = 2
            set_fat16(fat, first, value)
        for copy in range(fats):
            off = (reserved + copy * fat_secs) * bps
            image[off:off + len(fat)] = fat
        f.seek(0)
        f.write(image)


def build_base(label, fat_bits, fmt=None):
    boot = os.path.join(BUILDDIR, f"{label}_boot.bin")
    kernel = os.path.join(BUILDDIR, f"{label}_kernel.bin")
    img = os.path.join(BUILDDIR, f"{label}.img")
    boot_src = "src/boot.asm"
    fmt = fmt or ("hd32m" if fat_bits == 16 else "1440k")
    run_cmd(["nasm", f"-DFAT{fat_bits}=1", "-f", "bin", boot_src, "-o", boot])
    run_cmd(["nasm", "-f", "bin", "src/kernel.asm", "-o", kernel])
    args = ["python3", "scripts/mkimage.py"]
    if fat_bits == 16:
        args.append(f"--format={fmt}")
    args.extend([boot, kernel, img])
    run_cmd(args)
    return img


def cluster_lba(layout, cluster):
    return layout["data_start"] + (cluster - 2) * layout["spc"]


def cluster_offset(layout, cluster):
    return cluster_lba(layout, cluster) * layout["bps"]


def find_root_entry(image, layout, raw_name):
    root_off = (layout["reserved"] + layout["fats"] * layout["fat_secs"]) * layout["bps"]
    for index in range(layout["root_entries"]):
        off = root_off + index * 32
        if image[off] == 0:
            break
        if image[off:off + 11] == raw_name:
            return off
    raise RuntimeError(f"missing root entry {raw_name!r}")


def relocate_kernel_to_cluster(img_path, first_cluster):
    with open(img_path, "r+b") as f:
        image = bytearray(f.read())
        layout = bpb_layout(image)
        entry_off = find_root_entry(image, layout, b"KERNEL  SYS")
        old_first = struct.unpack_from("<H", image, entry_off + 26)[0]
        size = struct.unpack_from("<I", image, entry_off + 28)[0]
        cluster_bytes = layout["bps"] * layout["spc"]
        cluster_count = (size + cluster_bytes - 1) // cluster_bytes
        if first_cluster + cluster_count - 1 >= layout["max_cluster"]:
            raise RuntimeError("relocated kernel would exceed FAT16 image")
        data = bytearray(cluster_count * cluster_bytes)
        for i in range(cluster_count):
            src = cluster_offset(layout, old_first + i)
            dst = i * cluster_bytes
            data[dst:dst + cluster_bytes] = image[src:src + cluster_bytes]
        for i in range(cluster_count):
            dst = cluster_offset(layout, first_cluster + i)
            src = i * cluster_bytes
            image[dst:dst + cluster_bytes] = data[src:src + cluster_bytes]
        for copy in range(layout["fats"]):
            fat_off = (layout["reserved"] + copy * layout["fat_secs"]) * layout["bps"]
            fat = bytearray(image[fat_off:fat_off + layout["fat_secs"] * layout["bps"]])
            for i in range(cluster_count):
                value = first_cluster + i + 1 if i < cluster_count - 1 else 0xFFFF
                set_fat16(fat, first_cluster + i, value)
            image[fat_off:fat_off + len(fat)] = fat
        struct.pack_into("<H", image, entry_off + 26, first_cluster)
        f.seek(0)
        f.write(image)
        return cluster_lba(layout, first_cluster)


def run_case(base_img, label, fat_bits, value, boot_order):
    img = os.path.join(BUILDDIR, f"{label}.img")
    shutil.copyfile(base_img, img)
    corrupt_kernel_next(img, fat_bits, value)
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={img},format=raw" + (",if=floppy" if fat_bits == 12 else ""),
        "-boot", f"order={boot_order}",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT, stop_markers=("NoK", "LainDOS booted", "EXC "))
    failed = False
    if "NoK" in output:
        print(f"  PASS: {label} failed in boot loader")
    else:
        print(f"  FAIL: {label} missing NoK")
        failed = True
    for marker in ["LainDOS booted", "EXC ", "HALT"]:
        if marker in output:
            print(f"  FAIL: {label} unexpected '{marker}'")
            failed = True
    if failed:
        print(f"\n--- {label} serial output ---")
        print(output)
        print("--- end ---")
    return not failed


def run_success_case(img, label):
    output, _ = run_qemu_capture([
        QEMU,
        "-drive", f"file={img},format=raw",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], TIMEOUT, stop_markers=("LainDOS booted", "NoK", "EXC "))
    failed = False
    if "LainDOS booted" in output:
        print(f"  PASS: {label} reached kernel")
    else:
        print(f"  FAIL: {label} did not reach kernel")
        failed = True
    for marker in ["NoK", "EXC "]:
        if marker in output:
            print(f"  FAIL: {label} unexpected '{marker}'")
            failed = True
    if failed:
        print(f"\n--- {label} serial output ---")
        print(output)
        print("--- end ---")
    return not failed


def main():
    os.makedirs(BUILDDIR, exist_ok=True)
    fat12_img = build_base("bootchain12_base", 12)
    fat16_img = build_base("bootchain16_base", 16)
    fat16_wrap_img = build_base("bootchain16_wrap_base", 16, "hd160m")
    with open(fat12_img, "rb") as f:
        fat12_max = bpb_geometry(f.read())[5]
    with open(fat16_img, "rb") as f:
        fat16_max = bpb_geometry(f.read())[5]
    cases = [
        (fat12_img, "fat12_cluster0", 12, 0, "a"),
        (fat12_img, "fat12_cluster1", 12, 1, "a"),
        (fat12_img, "fat12_reserved", 12, 0xFF0, "a"),
        (fat12_img, "fat12_bad_cluster", 12, 0xFF7, "a"),
        (fat12_img, "fat12_out_of_range", 12, fat12_max, "a"),
        (fat16_img, "fat16_cluster0", 16, 0, "c"),
        (fat16_img, "fat16_cluster1", 16, 1, "c"),
        (fat16_img, "fat16_reserved", 16, 0xFFF0, "c"),
        (fat16_img, "fat16_bad_cluster", 16, 0xFFF7, "c"),
        (fat16_img, "fat16_out_of_range", 16, fat16_max, "c"),
    ]
    ok = True
    for args in cases:
        ok = run_case(*args) and ok
    with open(fat16_wrap_img, "rb") as f:
        layout = bpb_layout(f.read())
    first_lba = 0x10000 - layout["spc"] + 1
    wrap_cluster = ((first_lba - layout["data_start"] + layout["spc"] - 1)
                    // layout["spc"] + 2)
    start_lba = relocate_kernel_to_cluster(fat16_wrap_img, wrap_cluster)
    assert start_lba <= 0xFFFF < start_lba + layout["spc"]
    ok = run_success_case(fat16_wrap_img, "fat16_lba65535_wrap") and ok
    if not ok:
        sys.exit(1)
    print("\nBoot FAT chain bounds test passed.")


if __name__ == "__main__":
    main()
