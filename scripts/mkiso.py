#!/usr/bin/env python3
import os
import struct
import sys

SECTOR = 2048
PVD_LBA = 16
VDT_LBA = 17
PATH_TABLE_LBA = 18
ROOT_LBA = 19
FIRST_DATA_LBA = 20


def both32(value):
    return struct.pack("<I", value) + struct.pack(">I", value)


def both16(value):
    return struct.pack("<H", value) + struct.pack(">H", value)


def record(extent, size, flags, ident):
    if isinstance(ident, str):
        ident = ident.encode("ascii")
    rec_len = 33 + len(ident)
    if rec_len & 1:
        rec_len += 1
    rec = bytearray(rec_len)
    rec[0] = rec_len
    rec[2:10] = both32(extent)
    rec[10:18] = both32(size)
    rec[18:25] = bytes([126, 6, 9, 0, 0, 0, 0])
    rec[25] = flags
    rec[28:32] = both16(1)
    rec[32] = len(ident)
    rec[33:33 + len(ident)] = ident
    return bytes(rec)


def pad_sector(data):
    if len(data) > SECTOR:
        raise RuntimeError("single-directory test ISO overflow")
    return data + bytes(SECTOR - len(data))


def iso_file_name(path):
    name = os.path.basename(path).upper()
    if "." in name:
        base, ext = name.split(".", 1)
        return f"{base[:8]}.{ext[:3]};1"
    return f"{name[:8]}.;1"


def iso_dir_name(path):
    return os.path.basename(path).upper()[:8]


def split_iso_path(path):
    parts = [part for part in path.replace("\\", "/").split("/") if part]
    if not parts:
        raise RuntimeError("empty ISO path")
    return parts


def make_dir(name, parent=None):
    return {
        "name": name,
        "parent": parent,
        "dirs": {},
        "files": [],
        "lba": 0,
        "path_index": 0,
    }


def add_file(root, iso_path, host_path):
    parts = split_iso_path(iso_path)
    cur = root
    for part in parts[:-1]:
        name = iso_dir_name(part)
        if name not in cur["dirs"]:
            cur["dirs"][name] = make_dir(name, cur)
        cur = cur["dirs"][name]
    with open(host_path, "rb") as f:
        data = f.read()
    cur["files"].append({
        "ident": iso_file_name(parts[-1]),
        "data": data,
        "lba": 0,
    })


def collect_dirs(root):
    dirs = [root]
    idx = 0
    while idx < len(dirs):
        dirs.extend(dirs[idx]["dirs"].values())
        idx += 1
    return dirs


def path_table_entry(directory):
    if directory["parent"] is None:
        ident = b"\x00"
        parent_idx = 1
    else:
        ident = directory["name"].encode("ascii")
        parent_idx = directory["parent"]["path_index"]
    entry = bytearray()
    entry.append(len(ident))
    entry.append(0)
    entry.extend(struct.pack("<I", directory["lba"]))
    entry.extend(struct.pack("<H", parent_idx))
    entry.extend(ident)
    if len(entry) & 1:
        entry.append(0)
    return bytes(entry)


def build_path_table(dirs):
    return b"".join(path_table_entry(directory) for directory in dirs)


def dir_record_lengths(directory):
    lengths = [len(record(0, 0, 2, b"\x00")), len(record(0, 0, 2, b"\x01"))]
    for child in directory["dirs"].values():
        lengths.append(len(record(0, 0, 2, child["name"])))
    for entry in directory["files"]:
        lengths.append(len(record(0, 0, 0, entry["ident"])))
    return lengths


def compute_dir_size(directory):
    pos = 0
    for rec_len in dir_record_lengths(directory):
        rem = SECTOR - (pos % SECTOR)
        if rec_len > rem:
            pos += rem
        pos += rec_len
    sectors = max(1, (pos + SECTOR - 1) // SECTOR)
    directory["sectors"] = sectors
    directory["size"] = sectors * SECTOR


def build_dir_data(directory):
    parent = directory["parent"] if directory["parent"] is not None else directory
    recs = [record(directory["lba"], directory["size"], 2, b"\x00"),
            record(parent["lba"], parent["size"], 2, b"\x01")]
    for child in directory["dirs"].values():
        recs.append(record(child["lba"], child["size"], 2, child["name"]))
    for entry in directory["files"]:
        recs.append(record(entry["lba"], len(entry["data"]), 0, entry["ident"]))
    data = bytearray()
    for rec in recs:
        rem = SECTOR - (len(data) % SECTOR)
        if len(rec) > rem:
            data.extend(bytes(rem))
        data.extend(rec)
    total = directory["sectors"] * SECTOR
    if len(data) > total:
        raise RuntimeError("directory data exceeded computed size")
    return bytes(data) + bytes(total - len(data))


def build_iso(output, files):
    root = make_dir("", None)
    for iso_path, host_path in files:
        add_file(root, iso_path, host_path)

    dirs = collect_dirs(root)
    for directory in dirs:
        compute_dir_size(directory)
    if root["sectors"] != 1:
        raise RuntimeError("root directory must fit one sector")
    root["lba"] = ROOT_LBA
    next_lba = FIRST_DATA_LBA
    for idx, directory in enumerate(dirs, 1):
        directory["path_index"] = idx
        if directory is not root:
            directory["lba"] = next_lba
            next_lba += directory["sectors"]

    file_count = 0
    for directory in dirs:
        for entry in directory["files"]:
            sectors = max(1, (len(entry["data"]) + SECTOR - 1) // SECTOR)
            entry["lba"] = next_lba
            file_count += 1
            next_lba += sectors

    path_table = build_path_table(dirs)
    if len(path_table) > SECTOR:
        raise RuntimeError("test ISO path table overflow")

    total_sectors = next_lba
    image = bytearray(SECTOR * total_sectors)

    for directory in dirs:
        data = build_dir_data(directory)
        image[directory["lba"] * SECTOR:directory["lba"] * SECTOR + len(data)] = data

    for directory in dirs:
        for entry in directory["files"]:
            off = entry["lba"] * SECTOR
            image[off:off + len(entry["data"])] = entry["data"]

    pvd = bytearray(SECTOR)
    pvd[0] = 1
    pvd[1:6] = b"CD001"
    pvd[6] = 1
    pvd[8:40] = b"LAINDOS".ljust(32)
    pvd[40:72] = b"LAINCD".ljust(32)
    pvd[80:88] = both32(total_sectors)
    pvd[120:124] = both16(1)
    pvd[124:128] = both16(1)
    pvd[128:132] = both16(SECTOR)
    pvd[132:140] = both32(len(path_table))
    pvd[140:144] = struct.pack("<I", PATH_TABLE_LBA)
    pvd[156:190] = record(ROOT_LBA, root["size"], 2, b"\x00")[:34]
    image[PVD_LBA * SECTOR:(PVD_LBA + 1) * SECTOR] = pvd

    vdt = bytearray(SECTOR)
    vdt[0] = 255
    vdt[1:6] = b"CD001"
    vdt[6] = 1
    image[VDT_LBA * SECTOR:(VDT_LBA + 1) * SECTOR] = vdt

    image[PATH_TABLE_LBA * SECTOR:PATH_TABLE_LBA * SECTOR + len(path_table)] = path_table

    with open(output, "wb") as f:
        f.write(image)
    print(f"Created {output}: {len(image)} bytes, {file_count} file(s)")


def main():
    if len(sys.argv) < 3:
        print("usage: mkiso.py output.iso ISO_NAME=host_path [...]", file=sys.stderr)
        sys.exit(1)
    files = []
    for arg in sys.argv[2:]:
        if "=" not in arg:
            print(f"expected ISO_NAME=host_path: {arg}", file=sys.stderr)
            sys.exit(1)
        iso_path, host_path = arg.split("=", 1)
        files.append((iso_path, host_path))
    build_iso(sys.argv[1], files)


if __name__ == "__main__":
    main()
