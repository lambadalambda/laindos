#!/usr/bin/env python3
import os
import struct
import sys

SECTOR = 2048
PVD_LBA = 16
VDT_LBA = 17
PATH_TABLE_LBA = 18
ROOT_LBA = 19
FIRST_FILE_LBA = 20


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


def iso_name(path):
    name = os.path.basename(path).upper()
    if "." in name:
        base, ext = name.split(".", 1)
        return f"{base[:8]}.{ext[:3]};1"
    return f"{name[:8]}.;1"


def build_iso(output, files):
    entries = []
    next_lba = FIRST_FILE_LBA
    image = bytearray(SECTOR * FIRST_FILE_LBA)
    for iso_path, host_path in files:
        with open(host_path, "rb") as f:
            data = f.read()
        sectors = max(1, (len(data) + SECTOR - 1) // SECTOR)
        entries.append((iso_name(iso_path), next_lba, len(data), data))
        next_lba += sectors

    total_sectors = next_lba
    image.extend(bytes(SECTOR * (total_sectors - FIRST_FILE_LBA)))

    root = bytearray()
    root.extend(record(ROOT_LBA, SECTOR, 2, b"\x00"))
    root.extend(record(ROOT_LBA, SECTOR, 2, b"\x01"))
    for name, lba, size, _data in entries:
        root.extend(record(lba, size, 0, name))
    image[ROOT_LBA * SECTOR:(ROOT_LBA + 1) * SECTOR] = pad_sector(bytes(root))

    for _name, lba, _size, data in entries:
        off = lba * SECTOR
        image[off:off + len(data)] = data

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
    pvd[132:140] = both32(10)
    pvd[140:144] = struct.pack("<I", PATH_TABLE_LBA)
    pvd[156:190] = record(ROOT_LBA, SECTOR, 2, b"\x00")[:34]
    image[PVD_LBA * SECTOR:(PVD_LBA + 1) * SECTOR] = pvd

    vdt = bytearray(SECTOR)
    vdt[0] = 255
    vdt[1:6] = b"CD001"
    vdt[6] = 1
    image[VDT_LBA * SECTOR:(VDT_LBA + 1) * SECTOR] = vdt

    path_table = bytearray(SECTOR)
    path_table[0] = 1
    path_table[2:6] = struct.pack("<I", ROOT_LBA)
    path_table[6:8] = struct.pack("<H", 1)
    path_table[8] = 1
    image[PATH_TABLE_LBA * SECTOR:(PATH_TABLE_LBA + 1) * SECTOR] = path_table

    with open(output, "wb") as f:
        f.write(image)
    print(f"Created {output}: {len(image)} bytes, {len(entries)} file(s)")


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
