#!/usr/bin/env python3
import sys
import struct

SECTOR_SIZE = 512
TOTAL_SECTORS = 2880
IMAGE_SIZE = SECTOR_SIZE * TOTAL_SECTORS

BYTES_PER_SEC = 512
SEC_PER_CLUS = 1
RSVD_SEC_CNT = 1
NUM_FATS = 2
ROOT_ENT_CNT = 224
FAT_SZ = 9
SEC_PER_TRK = 18
NUM_HEADS = 2

FAT_START = RSVD_SEC_CNT
ROOT_START = FAT_START + NUM_FATS * FAT_SZ
ROOT_SECS = (ROOT_ENT_CNT * 32 + BYTES_PER_SEC - 1) // BYTES_PER_SEC
DATA_START = ROOT_START + ROOT_SECS

FAT12_EOC = 0xFF8


def fat12_entries_per_sector():
    return (SECTOR_SIZE * 2) // 3


def set_fat12_entry(fat_data, cluster, value):
    offset = cluster + (cluster >> 1)
    if cluster & 1:
        fat_data[offset] = (fat_data[offset] & 0x0F) | ((value & 0x0F) << 4)
        fat_data[offset + 1] = (value >> 4) & 0xFF
    else:
        fat_data[offset] = value & 0xFF
        fat_data[offset + 1] = (fat_data[offset + 1] & 0xF0) | ((value >> 8) & 0x0F)


def make_root_entry(name, ext, cluster, size, attr=0x20):
    entry = bytearray(32)
    entry[0:8] = name.ljust(8)[:8].encode('ascii')
    entry[8:11] = ext.ljust(3)[:3].encode('ascii')
    entry[11] = attr
    struct.pack_into('<H', entry, 26, cluster)
    struct.pack_into('<I', entry, 28, size)
    return entry


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} boot.bin kernel.bin disk.img", file=sys.stderr)
        sys.exit(1)

    boot_path = sys.argv[1]
    kernel_path = sys.argv[2]
    output_path = sys.argv[3]

    with open(boot_path, 'rb') as f:
        boot_data = f.read()
    if len(boot_data) != SECTOR_SIZE:
        print(f"Error: boot sector is {len(boot_data)} bytes, expected {SECTOR_SIZE}", file=sys.stderr)
        sys.exit(1)

    with open(kernel_path, 'rb') as f:
        kernel_data = f.read()

    image = bytearray(IMAGE_SIZE)

    image[0:SECTOR_SIZE] = boot_data

    fat = bytearray(FAT_SZ * SECTOR_SIZE)
    set_fat12_entry(fat, 0, 0xFF0)
    set_fat12_entry(fat, 1, 0xFFF)

    clusters_needed = (len(kernel_data) + BYTES_PER_SEC - 1) // BYTES_PER_SEC
    first_cluster = 2

    for i in range(clusters_needed):
        cluster = first_cluster + i
        if i < clusters_needed - 1:
            next_cluster = cluster + 1
        else:
            next_cluster = FAT12_EOC
        set_fat12_entry(fat, cluster, next_cluster)

    fat1_offset = FAT_START * SECTOR_SIZE
    image[fat1_offset:fat1_offset + len(fat)] = fat
    fat2_offset = (FAT_START + FAT_SZ) * SECTOR_SIZE
    image[fat2_offset:fat2_offset + len(fat)] = fat

    root_offset = ROOT_START * SECTOR_SIZE
    entry = make_root_entry("KERNEL", "SYS", first_cluster, len(kernel_data))
    image[root_offset:root_offset + 32] = entry

    data_offset = DATA_START * SECTOR_SIZE
    kernel_offset = data_offset + (first_cluster - 2) * SEC_PER_CLUS * BYTES_PER_SEC
    image[kernel_offset:kernel_offset + len(kernel_data)] = kernel_data

    with open(output_path, 'wb') as f:
        f.write(image)

    print(f"Created {output_path}: {IMAGE_SIZE} bytes, "
          f"kernel {len(kernel_data)} bytes in {clusters_needed} cluster(s) starting at cluster {first_cluster}")


if __name__ == '__main__':
    main()
