#!/usr/bin/env python3
"""Build a bootable hard-disk image from local media not in FreeDOS.VHD."""
import os
import shutil
import struct
import subprocess
import sys
import zipfile

import build_games_hd_all as games


BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "extras_hd_boot.bin")
KERNEL = os.path.join(BUILDDIR, "extras_hd_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
MEM = os.path.join(BUILDDIR, "mem.com")
IMG = os.path.join(BUILDDIR, "extras_hd.img")
README = os.path.join(BUILDDIR, "extras.txt")

NORTON_ARCHIVE = "vendor/003064_norton_commander.7z"
NORTON_ARCHIVE_DIR = os.path.join(BUILDDIR, "extras_norton_archive")
NORTON_FILES_DIR = os.path.join(BUILDDIR, "extras_norton")
CIV_ARCHIVE = "vendor/sid-meiers-civilization-au.zip"
CIV_FILES_DIR = os.path.join(BUILDDIR, "extras_civ")
STUNT_ARCHIVE = "vendor/002514_stunt_island.7z"
STUNT_ARCHIVE_DIR = os.path.join(BUILDDIR, "extras_stunt_archive")
STUNT_FILES_DIR = os.path.join(BUILDDIR, "extras_stunt_source")


def require_file(path):
    if not os.path.isfile(path):
        print(f"Missing {path}", file=sys.stderr)
        sys.exit(1)


def clean_dir(path):
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(path)


def fat_next(data, fat_off, cluster, bits):
    if bits == 16:
        return struct.unpack_from("<H", data, fat_off + cluster * 2)[0]
    off = fat_off + cluster + cluster // 2
    value = data[off] | (data[off + 1] << 8)
    return value >> 4 if cluster & 1 else value & 0x0FFF


def read_chain(data, bps, spc, fat_off, data_off, bits, cluster, size=None):
    chunks = []
    seen = set()
    eoc = 0xFFF8 if bits == 16 else 0xFF8
    while 2 <= cluster < eoc and cluster not in seen:
        seen.add(cluster)
        off = data_off + (cluster - 2) * bps * spc
        chunks.append(data[off:off + bps * spc])
        cluster = fat_next(data, fat_off, cluster, bits)
    blob = b"".join(chunks)
    return blob if size is None else blob[:size]


def entry_name(entry):
    name = entry[:8].decode("ascii", errors="replace").rstrip()
    ext = entry[8:11].decode("ascii", errors="replace").rstrip()
    return name + (f".{ext}" if ext else "")


def write_merged(path, data):
    if os.path.exists(path):
        with open(path, "rb") as f:
            old = f.read()
        if old != data:
            print(f"Conflicting duplicate file while extracting media: {path}", file=sys.stderr)
            sys.exit(1)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def extract_dir(data, bps, spc, fat_off, data_off, bits, dir_data, output_dir):
    for off in range(0, len(dir_data), 32):
        entry = dir_data[off:off + 32]
        if len(entry) < 32 or entry[0] == 0:
            break
        attr = entry[11]
        if entry[0] == 0xE5 or attr == 0x0F or attr & 0x08:
            continue
        name = entry_name(entry)
        if name in (".", ".."):
            continue
        cluster = struct.unpack_from("<H", entry, 26)[0]
        size = struct.unpack_from("<I", entry, 28)[0]
        path = os.path.join(output_dir, name)
        if attr & 0x10:
            os.makedirs(path, exist_ok=True)
            child = read_chain(data, bps, spc, fat_off, data_off, bits, cluster)
            extract_dir(data, bps, spc, fat_off, data_off, bits, child, path)
        else:
            write_merged(path, read_chain(data, bps, spc, fat_off, data_off, bits, cluster, size))


def extract_fat_image(image_path, output_dir):
    with open(image_path, "rb") as f:
        data = f.read()
    bps = struct.unpack_from("<H", data, 11)[0]
    spc = data[13]
    reserved = struct.unpack_from("<H", data, 14)[0]
    fat_count = data[16]
    root_entries = struct.unpack_from("<H", data, 17)[0]
    total = struct.unpack_from("<H", data, 19)[0] or struct.unpack_from("<I", data, 32)[0]
    sectors_per_fat = struct.unpack_from("<H", data, 22)[0]
    root_sectors = (root_entries * 32 + bps - 1) // bps
    fat_off = reserved * bps
    root_off = (reserved + fat_count * sectors_per_fat) * bps
    data_off = (reserved + fat_count * sectors_per_fat + root_sectors) * bps
    data_sectors = total - (reserved + fat_count * sectors_per_fat + root_sectors)
    bits = 12 if data_sectors // spc < 4085 else 16
    root_data = data[root_off:root_off + root_entries * 32]
    extract_dir(data, bps, spc, fat_off, data_off, bits, root_data, output_dir)


def extract_7z(archive, output_dir):
    require_file(archive)
    if shutil.which("bsdtar") is None:
        print(f"Missing bsdtar needed to extract {archive}", file=sys.stderr)
        sys.exit(1)
    clean_dir(output_dir)
    games.run(["bsdtar", "-xf", archive, "-C", output_dir])


def extract_norton():
    clean_dir(NORTON_FILES_DIR)
    extract_7z(NORTON_ARCHIVE, NORTON_ARCHIVE_DIR)
    disk_dir = os.path.join(NORTON_ARCHIVE_DIR, "003064_norton_commander")
    for name in sorted(os.listdir(disk_dir), key=str.upper):
        if name.lower().endswith(".img"):
            extract_fat_image(os.path.join(disk_dir, name), NORTON_FILES_DIR)


def extract_civilization():
    require_file(CIV_ARCHIVE)
    clean_dir(CIV_FILES_DIR)
    with zipfile.ZipFile(CIV_ARCHIVE) as archive:
        for info in sorted(archive.infolist(), key=lambda item: item.filename.upper()):
            if info.is_dir() or not info.filename.lower().endswith(".img"):
                continue
            image_path = os.path.join(CIV_FILES_DIR, os.path.basename(info.filename))
            with archive.open(info) as src, open(image_path, "wb") as dst:
                dst.write(src.read())
            extract_fat_image(image_path, CIV_FILES_DIR)
            os.remove(image_path)


def extract_stunt_source():
    clean_dir(STUNT_FILES_DIR)
    extract_7z(STUNT_ARCHIVE, STUNT_ARCHIVE_DIR)
    for root, _, names in os.walk(STUNT_ARCHIVE_DIR):
        for name in sorted(names, key=str.upper):
            if name.lower().endswith(".img"):
                extract_fat_image(os.path.join(root, name), STUNT_FILES_DIR)


def add_dir(cmd, dos_dir, host_dir):
    cmd.extend(f"{dos_dir}:{path}" for path in games.files_in(host_dir))


def write_readme():
    text = (
        "LainDOS local extras image\r\n"
        "\r\n"
        "Directories: M1DEMO MONKEY MI2DEMO MI2 SIMON ASCEND WOLF3D NC CIV RES SETS VAULT\r\n"
        "Norton Commander: CD NC, then NC\r\n"
        "Civilization: CD CIV, then CIV\r\n"
        "Stunt Island installer source is in the root plus RES, SETS, and VAULT.\r\n"
        "Run INSTALL from C:\\, then CD STUNTISL and run STUNT after install.\r\n"
    )
    with open(README, "wb") as f:
        f.write(text.encode("ascii"))


def prepare_standard_games():
    games.extract_flat(games.MONKEY_FULL_ZIP, games.MONKEY_FULL_DIR)
    games.safe_extract(games.MI2_DEMO_ZIP, games.MI2_DEMO_DIR)
    games.safe_extract(games.MI2_FULL_ZIP, games.MI2_FULL_DIR)
    games.extract_flat(games.SIMON_DEMO_ZIP, games.SIMON_DEMO_DIR)
    games.safe_extract(games.ASCENDANCY_ZIP, games.ASCENDANCY_DIR)
    wolf3d_files = games.extract_required_flat(games.WOLF3D_ZIP, games.WOLF3D_DIR, games.WOLF3D_REQUIRED, "Wolf3D")
    games.install_ascendancy_cd_cob()
    return wolf3d_files


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)

    os.makedirs(BUILDDIR, exist_ok=True)
    wolf3d_files = prepare_standard_games()
    extract_norton()
    extract_civilization()
    extract_stunt_source()
    write_readme()

    games.run(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    games.run(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    games.run(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    games.run(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    games.run(["nasm", "-f", "bin", "programs/free.asm", "-o", MEM])

    m1_demo = [
        "vendor/midemo.exe",
        "vendor/disk01.lec",
        "vendor/000.lfl",
        "vendor/901.lfl",
        "vendor/902.lfl",
        "vendor/904.lfl",
        "vendor/monkey.txt",
        "vendor/readme",
    ]
    games.require(m1_demo)
    mi2_full_files = games.files_in(os.path.join(games.MI2_FULL_DIR, "mi2"))
    ascendancy_files = games.files_in(games.ASCENDANCY_FILES_DIR)

    cmd = [
        "python3", "scripts/mkimage.py", "--format=hd160m",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        FREE,
        MEM,
        README,
    ]
    cmd.extend(games.files_in(STUNT_FILES_DIR))
    cmd.extend(f"M1DEMO:{path}" for path in m1_demo)
    cmd.extend(f"MONKEY:{path}" for path in games.files_in(games.MONKEY_FULL_DIR))
    cmd.extend(f"MI2DEMO:{path}" for path in games.files_in(games.MI2_DEMO_DIR))
    cmd.extend(f"MI2:{path}" for path in mi2_full_files)
    cmd.extend(f"SIMON:{path}" for path in games.files_in(games.SIMON_DEMO_DIR))
    cmd.extend(f"ASCEND:{path}" for path in ascendancy_files)
    cmd.extend(f"WOLF3D:{path}" for path in wolf3d_files)
    add_dir(cmd, "NC", NORTON_FILES_DIR)
    add_dir(cmd, "CIV", CIV_FILES_DIR)
    for dirname in ("RES", "SETS", "VAULT", "PILOTS"):
        host_dir = os.path.join(STUNT_FILES_DIR, dirname)
        if os.path.isdir(host_dir):
            add_dir(cmd, dirname, host_dir)
    games.run(cmd)


if __name__ == "__main__":
    main()
