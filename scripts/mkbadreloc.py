#!/usr/bin/env python3
import struct
import sys

def make_badreloc_exe(path):
    reloc_off = 0x1C
    reloc_count = 1
    hdr_par = 4
    hdr_bytes = hdr_par * 16

    image_bytes = b"\xB8\x00\x4C\xCD\x21"
    total_pages = (hdr_bytes + len(image_bytes) + 511) // 512
    last_page_bytes = (hdr_bytes + len(image_bytes)) % 512

    header = struct.pack("<HHHHHHHHHHHHH",
        0x5A4D,
        last_page_bytes if last_page_bytes else 512,
        total_pages,
        reloc_count,
        hdr_par,
        0x0010,
        0xFFFF,
        0x0000,
        0xFFFE,
        0x0000,
        0x0000,
        0x0000,
        reloc_off,
    )

    reloc_table = struct.pack("<HH", 0x0000, 0xFFFF)

    with open(path, "wb") as f:
        f.write(header)
        f.write(reloc_table)
        f.write(b"\x00" * (hdr_bytes - len(header) - len(reloc_table)))
        f.write(image_bytes)


def make_noreloc_weird_exe(path):
    reloc_off = 0x0A0D
    reloc_count = 0
    hdr_par = 4
    hdr_bytes = hdr_par * 16

    image_bytes = b"\xB8\x00\x4C\xCD\x21"
    total = hdr_bytes + len(image_bytes)
    total_pages = (total + 511) // 512
    last_page_bytes = total % 512

    header = struct.pack("<HHHHHHHHHHHHH",
        0x5A4D,
        last_page_bytes if last_page_bytes else 512,
        total_pages,
        reloc_count,
        hdr_par,
        0x0010,
        0xFFFF,
        0x0000,
        0xFFFE,
        0x0000,
        0x0000,
        0x0000,
        reloc_off,
    )

    with open(path, "wb") as f:
        f.write(header)
        f.write(b"\x00" * (hdr_bytes - len(header)))
        f.write(image_bytes)

if __name__ == "__main__":
    make_badreloc_exe(sys.argv[1])
    if len(sys.argv) > 2:
        make_noreloc_weird_exe(sys.argv[2])
