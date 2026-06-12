#!/usr/bin/env python3
import os
import re
import struct
import sys

RAW_SECTOR = 2352
DATA_OFFSET = 16
DATA_SIZE = 2048


def parse_msf(text):
    minute, second, frame = (int(part) for part in text.split(":"))
    return (minute * 60 + second) * 75 + frame


def find_case_insensitive(directory, name):
    path = os.path.join(directory, name)
    if os.path.exists(path):
        return path
    wanted = name.upper()
    for entry in os.listdir(directory):
        if entry.upper() == wanted:
            return os.path.join(directory, entry)
    raise RuntimeError(f"cue references missing file {name}")


def parse_cue(cue_path):
    cue_dir = os.path.dirname(os.path.abspath(cue_path))
    current_file = None
    in_data_track = False
    file_re = re.compile(r'^FILE\s+"([^"]+)"\s+BINARY$', re.IGNORECASE)
    track_re = re.compile(r'^TRACK\s+\d+\s+(\S+)$', re.IGNORECASE)
    index_re = re.compile(r'^INDEX\s+0?1\s+(\d\d:\d\d:\d\d)$', re.IGNORECASE)
    with open(cue_path, "r", encoding="ascii") as cue:
        for raw_line in cue:
            line = raw_line.strip()
            match = file_re.match(line)
            if match:
                current_file = find_case_insensitive(cue_dir, match.group(1))
                in_data_track = False
                continue
            match = track_re.match(line)
            if match:
                in_data_track = match.group(1).upper() == "MODE1/2352"
                continue
            match = index_re.match(line)
            if in_data_track and match:
                return current_file, parse_msf(match.group(1))
    raise RuntimeError("cue has no MODE1/2352 INDEX 01 track")


def read_volume_size(bin_path, start_sector):
    with open(bin_path, "rb") as image:
        image.seek((start_sector + 16) * RAW_SECTOR + DATA_OFFSET)
        pvd = image.read(DATA_SIZE)
    if len(pvd) != DATA_SIZE or pvd[1:6] != b"CD001":
        raise RuntimeError("MODE1/2352 data track does not contain an ISO9660 PVD")
    le_size = struct.unpack_from("<I", pvd, 80)[0]
    be_size = struct.unpack_from(">I", pvd, 84)[0]
    if le_size != be_size:
        raise RuntimeError("ISO9660 PVD volume size endian fields do not match")
    return le_size


def extract(bin_path, start_sector, output_path):
    sector_count = read_volume_size(bin_path, start_sector)
    expected_size = sector_count * DATA_SIZE
    if os.path.exists(output_path) and os.path.getsize(output_path) == expected_size:
        print(f"Reusing {output_path}: {expected_size} bytes")
        return
    with open(bin_path, "rb") as src, open(output_path, "wb") as dst:
        for sector in range(sector_count):
            src.seek((start_sector + sector) * RAW_SECTOR + DATA_OFFSET)
            data = src.read(DATA_SIZE)
            if len(data) != DATA_SIZE:
                raise RuntimeError("short read while extracting MODE1/2352 data track")
            dst.write(data)
    print(f"Created {output_path}: {expected_size} bytes, {sector_count} sector(s)")


def main():
    if len(sys.argv) != 3:
        print("usage: extract_mode1_2352.py input.cue output.iso", file=sys.stderr)
        sys.exit(1)
    try:
        bin_path, start_sector = parse_cue(sys.argv[1])
        extract(bin_path, start_sector, sys.argv[2])
    except RuntimeError as err:
        print(str(err), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
