#!/usr/bin/env python3
"""Build a shell-booting hard disk image with all local game sets."""
import os
import shutil
import subprocess
import sys

from testlib import run_cmd
import zipfile

BUILDDIR = "build"
BOOT = os.path.join(BUILDDIR, "games_hd_all_boot.bin")
KERNEL = os.path.join(BUILDDIR, "games_hd_all_kernel.bin")
SHELL = os.path.join(BUILDDIR, "shell.com")
FREE = os.path.join(BUILDDIR, "free.com")
MEM = os.path.join(BUILDDIR, "mem.com")
TIME = os.path.join(BUILDDIR, "time.com")
IMG = os.path.join(BUILDDIR, "games_hd_all.img")

MONKEY_FULL_ZIP = "vendor/monkey_full.zip"
MI2_DEMO_ZIP = "vendor/mi2demo.zip"
MI2_FULL_ZIP = "vendor/Monkey_Island_2_-_LeChucks_Revenge_1991.zip"
SIMON_DEMO_ZIP = "vendor/simon1demo.zip"
ASCENDANCY_ZIP = "vendor/Ascendancy_1995.zip"
WOLF3D_ZIP = "vendor/wolf3dsw.zip"
MONKEY_FULL_DIR = os.path.join(BUILDDIR, "monkey_full_files")
MI2_DEMO_DIR = os.path.join(BUILDDIR, "mi2demo")
MI2_FULL_DIR = os.path.join(BUILDDIR, "mi2full")
SIMON_DEMO_DIR = os.path.join(BUILDDIR, "simon1demo")
ASCENDANCY_DIR = os.path.join(BUILDDIR, "ascendancy")
WOLF3D_DIR = os.path.join(BUILDDIR, "wolf3d")
ASCENDANCY_FILES_DIR = os.path.join(ASCENDANCY_DIR, "ascendy")
ASCENDANCY_CD_IMG = os.path.join(ASCENDANCY_FILES_DIR, "cd", "ascendancy.img")
ASCENDANCY_CD_COB = os.path.join(ASCENDANCY_FILES_DIR, "ASCEND02.COB")
ASCENDANCY_COB_CFG = os.path.join(ASCENDANCY_FILES_DIR, "COB.CFG")
RAW_CD_SECTOR = 2352
ISO_SECTOR = 2048
RAW_CD_DATA_OFF = 16
WOLF3D_REQUIRED = {
    "AUDIOHED.WL1",
    "AUDIOT.WL1",
    "GAMEMAPS.WL1",
    "MAPHEAD.WL1",
    "VGADICT.WL1",
    "VGAGRAPH.WL1",
    "VGAHEAD.WL1",
    "VSWAP.WL1",
    "WOLF3D.EXE",
}


def safe_extract(zip_path, output_dir):
    if not os.path.isfile(zip_path):
        print(f"Missing {zip_path}", file=sys.stderr)
        sys.exit(1)
    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)
    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.namelist():
            parts = member.replace("\\", "/").split("/")
            if member.startswith("/") or ".." in parts or (parts and ":" in parts[0]):
                print(f"Unsafe zip member: {member}", file=sys.stderr)
                sys.exit(1)
        archive.extractall(output_dir)


def extract_flat(zip_path, output_dir):
    if not os.path.isfile(zip_path):
        print(f"Missing {zip_path}", file=sys.stderr)
        sys.exit(1)
    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            basename = os.path.basename(info.filename)
            if not basename:
                continue
            with archive.open(info) as src, open(os.path.join(output_dir, basename), "wb") as dst:
                dst.write(src.read())


def extract_required_flat(zip_path, output_dir, required, label):
    if not os.path.isfile(zip_path):
        print(f"Missing {zip_path}", file=sys.stderr)
        sys.exit(1)
    if os.path.isdir(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)
    extracted = []
    with zipfile.ZipFile(zip_path) as archive:
        names = {os.path.basename(info.filename).upper() for info in archive.infolist() if not info.is_dir()}
        missing = sorted(required - names)
        if missing:
            print(f"{label} archive is missing required files:", file=sys.stderr)
            for name in missing:
                print(f"  {name}", file=sys.stderr)
            sys.exit(1)
        for info in archive.infolist():
            if info.is_dir():
                continue
            basename = os.path.basename(info.filename).upper()
            if basename not in required:
                continue
            target = os.path.join(output_dir, basename)
            with archive.open(info) as src, open(target, "wb") as dst:
                dst.write(src.read())
            extracted.append(target)
    return sorted(extracted, key=lambda path: os.path.basename(path).upper())


def files_in(dirname):
    return [
        os.path.join(dirname, name)
        for name in sorted(os.listdir(dirname), key=str.upper)
        if os.path.isfile(os.path.join(dirname, name))
    ]


def raw_cd_sector(image, lba):
    start = lba * RAW_CD_SECTOR + RAW_CD_DATA_OFF
    return image[start:start + ISO_SECTOR]


def iso_dir_record(buf, off):
    length = buf[off]
    if length == 0:
        return None, 1
    if off + 33 > len(buf):
        return None, 1
    extent = int.from_bytes(buf[off + 2:off + 6], "little")
    size = int.from_bytes(buf[off + 10:off + 14], "little")
    flags = buf[off + 25]
    name_len = buf[off + 32]
    if off + 33 + name_len > len(buf):
        return None, 1
    raw_name = buf[off + 33:off + 33 + name_len]
    if raw_name == b"\x00":
        name = "."
    elif raw_name == b"\x01":
        name = ".."
    else:
        name = raw_name.decode("ascii").split(";", 1)[0].upper()
    return {"name": name, "extent": extent, "size": size, "dir": bool(flags & 2)}, length


def iso_read_dir(image, extent, size):
    count = (size + ISO_SECTOR - 1) // ISO_SECTOR
    data = b"".join(raw_cd_sector(image, extent + i) for i in range(count))
    off = 0
    entries = {}
    while off < len(data):
        if data[off] == 0:
            off = ((off // ISO_SECTOR) + 1) * ISO_SECTOR
            continue
        rec, length = iso_dir_record(data, off)
        off += length
        if rec and rec["name"] not in (".", ".."):
            entries[rec["name"]] = rec
    return entries


def iso_read_file(image, path_parts):
    pvd = raw_cd_sector(image, 16)
    if pvd[1:6] != b"CD001":
        print("Ascendancy CD image is not a raw Mode 1 ISO image", file=sys.stderr)
        sys.exit(1)
    root, _ = iso_dir_record(pvd, 156)
    current = root
    for part in path_parts:
        entries = iso_read_dir(image, current["extent"], current["size"])
        current = entries.get(part.upper())
        if current is None:
            print(f"Missing Ascendancy CD file: {'/'.join(path_parts)}", file=sys.stderr)
            sys.exit(1)
    if current["dir"]:
        print(f"Ascendancy CD path is a directory: {'/'.join(path_parts)}", file=sys.stderr)
        sys.exit(1)
    count = (current["size"] + ISO_SECTOR - 1) // ISO_SECTOR
    data = b"".join(raw_cd_sector(image, current["extent"] + i) for i in range(count))
    return data[:current["size"]]


def install_ascendancy_cd_cob():
    if not os.path.isfile(ASCENDANCY_CD_IMG):
        print(f"Missing Ascendancy CD image {ASCENDANCY_CD_IMG}", file=sys.stderr)
        sys.exit(1)
    with open(ASCENDANCY_CD_IMG, "rb") as f:
        cd_image = f.read()
    with open(ASCENDANCY_CD_COB, "wb") as f:
        f.write(iso_read_file(cd_image, ["DATA", "ASCEND02.COB"]))
    with open(ASCENDANCY_COB_CFG, "wb") as f:
        f.write(b"ASCEND00.COB\r\nASCEND01.COB\r\nASCEND02.COB\r\n")


def require(paths):
    missing = [path for path in paths if not os.path.isfile(path)]
    if missing:
        print("Missing game files:", file=sys.stderr)
        for path in missing:
            print(f"  {path}", file=sys.stderr)
        sys.exit(1)


def main():
    if not os.path.exists("src/boot.asm"):
        print("Run this script from the LainDOS project root.", file=sys.stderr)
        sys.exit(1)

    os.makedirs(BUILDDIR, exist_ok=True)
    extract_flat(MONKEY_FULL_ZIP, MONKEY_FULL_DIR)
    safe_extract(MI2_DEMO_ZIP, MI2_DEMO_DIR)
    safe_extract(MI2_FULL_ZIP, MI2_FULL_DIR)
    extract_flat(SIMON_DEMO_ZIP, SIMON_DEMO_DIR)
    safe_extract(ASCENDANCY_ZIP, ASCENDANCY_DIR)
    wolf3d_files = extract_required_flat(WOLF3D_ZIP, WOLF3D_DIR, WOLF3D_REQUIRED, "Wolf3D")
    install_ascendancy_cd_cob()

    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm",
        "-o", KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", SHELL])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", FREE])
    run_cmd(["nasm", "-f", "bin", "programs/free.asm", "-o", MEM])
    run_cmd(["nasm", "-f", "bin", "programs/time.asm", "-o", TIME])

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
    require(m1_demo)

    mi2_full_files = files_in(os.path.join(MI2_FULL_DIR, "mi2"))
    if not mi2_full_files:
        print(f"Missing extracted full MI2 files under {MI2_FULL_DIR}/mi2", file=sys.stderr)
        sys.exit(1)
    ascendancy_files = files_in(ASCENDANCY_FILES_DIR)
    if not ascendancy_files:
        print(f"Missing extracted Ascendancy files under {ASCENDANCY_FILES_DIR}", file=sys.stderr)
        sys.exit(1)

    cmd = [
        "python3", "scripts/mkimage.py", "--format=hd96m",
        BOOT,
        KERNEL,
        IMG,
        SHELL,
        FREE,
        MEM,
        TIME,
    ]
    cmd.extend(f"M1DEMO:{path}" for path in m1_demo)
    cmd.extend(f"MONKEY:{path}" for path in files_in(MONKEY_FULL_DIR))
    cmd.extend(f"MI2DEMO:{path}" for path in files_in(MI2_DEMO_DIR))
    cmd.extend(f"MI2:{path}" for path in mi2_full_files)
    cmd.extend(f"SIMON:{path}" for path in files_in(SIMON_DEMO_DIR))
    cmd.extend(f"ASCEND:{path}" for path in ascendancy_files)
    cmd.extend(f"WOLF3D:{path}" for path in wolf3d_files)
    run_cmd(cmd)


if __name__ == "__main__":
    main()
