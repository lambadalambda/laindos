#!/usr/bin/env python3
import struct
import sys


def make_reloc_overlay(path):
    reloc_off = 0x1D
    reloc_count = 200
    hdr_par = 64
    hdr_bytes = hdr_par * 16

    image_words = 256
    image = bytearray(struct.pack("<H", 0x1111) * image_words)
    total = hdr_bytes + len(image)
    total_pages = (total + 511) // 512
    last_page = total % 512

    header = bytearray(hdr_bytes)
    header[0:28] = struct.pack(
        "<HHHHHHHHHHHHHH",
        0x5A4D,
        last_page if last_page else 512,
        total_pages,
        reloc_count,
        hdr_par,
        0x0000,
        0xFFFF,
        0x0000,
        0xFFFE,
        0x0000,
        0x0000,
        0x0000,
        reloc_off,
        0x0000,
    )
    for i in range(reloc_count):
        entry = struct.pack("<HH", (i * 2) % (image_words * 2), 0)
        header[reloc_off + i * 4:reloc_off + i * 4 + 4] = entry

    with open(path, "wb") as f:
        f.write(header)
        f.write(image)
    print(f"Created {path}: {total} bytes, {reloc_count} relocations at 0x{reloc_off:X}")


if __name__ == "__main__":
    make_reloc_overlay(sys.argv[1])
