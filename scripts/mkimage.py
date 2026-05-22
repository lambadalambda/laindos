#!/usr/bin/env python3
import sys
import struct
import os

BYTES_PER_SEC = 512
RSVD_SEC_CNT = 1
NUM_FATS = 2
FORMATS = {
    '1440k': {
        'total_sectors': 2880,
        'sec_per_clus': 1,
        'root_ent_cnt': 224,
        'fat_sz': 9,
        'sec_per_trk': 18,
        'num_heads': 2,
    },
    '2880k': {
        'total_sectors': 5760,
        'sec_per_clus': 2,
        'root_ent_cnt': 224,
        'fat_sz': 9,
        'sec_per_trk': 36,
        'num_heads': 2,
    },
}

fmt = FORMATS['1440k']
SECTOR_SIZE = 512
TOTAL_SECTORS = fmt['total_sectors']
SEC_PER_CLUS = fmt['sec_per_clus']
ROOT_ENT_CNT = fmt['root_ent_cnt']
FAT_SZ = fmt['fat_sz']
SEC_PER_TRK = fmt['sec_per_trk']
NUM_HEADS = fmt['num_heads']
IMAGE_SIZE = SECTOR_SIZE * TOTAL_SECTORS
FAT_START = RSVD_SEC_CNT
ROOT_START = FAT_START + NUM_FATS * FAT_SZ
ROOT_SECS = (ROOT_ENT_CNT * 32 + BYTES_PER_SEC - 1) // BYTES_PER_SEC
DATA_START = ROOT_START + ROOT_SECS

FAT12_EOC = 0xFF8
DIR_ATTR = 0x10


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


def alloc_clusters(fat, next_cluster, count):
    first = next_cluster
    for i in range(count):
        c = first + i
        nxt = c + 1 if i < count - 1 else FAT12_EOC
        set_fat12_entry(fat, c, nxt)
    return first, count


def write_cluster_data(image, cluster, data, data_offset=0):
    cluster_off = DATA_START * SECTOR_SIZE + (cluster - 2) * SEC_PER_CLUS * BYTES_PER_SEC
    chunk = BYTES_PER_SEC * SEC_PER_CLUS
    end = min(len(data), data_offset + chunk)
    image[cluster_off:cluster_off + (end - data_offset)] = data[data_offset:end]


class Fat12Image:
    def __init__(self):
        self.image = bytearray(IMAGE_SIZE)
        self.fat = bytearray(FAT_SZ * SECTOR_SIZE)
        set_fat12_entry(self.fat, 0, 0xFF0)
        set_fat12_entry(self.fat, 1, 0xFFF)
        self.next_cluster = 2
        self.root_entries = []
        self.subdirs = {}

    def alloc_cluster(self):
        c = self.next_cluster
        self.next_cluster += 1
        return c

    def alloc_clusters(self, count):
        first = self.next_cluster
        self.next_cluster += count
        max_cluster = (TOTAL_SECTORS - DATA_START) // SEC_PER_CLUS + 1
        if self.next_cluster > max_cluster:
            raise RuntimeError("disk image is full")
        for i in range(count):
            nxt = first + i + 1 if i < count - 1 else FAT12_EOC
            set_fat12_entry(self.fat, first + i, nxt)
        return first

    def add_file_to_root(self, name, ext, data, attr=0x20):
        cluster_bytes = BYTES_PER_SEC * SEC_PER_CLUS
        num_clusters = max(1, (len(data) + cluster_bytes - 1) // cluster_bytes)
        first = self.alloc_clusters(num_clusters)
        for i in range(num_clusters):
            c = first + i
            off = i * BYTES_PER_SEC * SEC_PER_CLUS
            write_cluster_data(self.image, c, data, off)
        entry = make_root_entry(name, ext, first, len(data), attr)
        self.root_entries.append(entry)

    def add_subdir(self, dirname):
        first_cluster = self.alloc_cluster()
        set_fat12_entry(self.fat, first_cluster, FAT12_EOC)
        entry = make_root_entry(dirname, "   ", first_cluster, 0, DIR_ATTR)
        self.root_entries.append(entry)
        self.subdirs[dirname] = {
            'cluster': first_cluster,
            'entries': [],
        }
        dot = bytearray(32)
        dot[0:8] = dirname.ljust(8)[:8].encode('ascii')
        dot[8:11] = b'   '
        dot[11] = DIR_ATTR
        struct.pack_into('<H', dot, 26, first_cluster)
        self.subdirs[dirname]['entries'].append(dot)
        dotdot = bytearray(32)
        dotdot[0:8] = b'.      '
        dotdot[8:11] = b'   '
        dotdot[11] = DIR_ATTR
        struct.pack_into('<H', dotdot, 26, 0)
        self.subdirs[dirname]['entries'].append(dotdot)
        return dirname

    def add_file_to_subdir(self, dirname, name, ext, data):
        if dirname not in self.subdirs:
            self.add_subdir(dirname)
        sd = self.subdirs[dirname]
        cluster_bytes = BYTES_PER_SEC * SEC_PER_CLUS
        num_clusters = max(1, (len(data) + cluster_bytes - 1) // cluster_bytes)
        first = self.alloc_clusters(num_clusters)
        for i in range(num_clusters):
            c = first + i
            off = i * BYTES_PER_SEC * SEC_PER_CLUS
            write_cluster_data(self.image, c, data, off)
        entry = make_root_entry(name, ext, first, len(data))
        sd['entries'].append(entry)

    def finalize(self):
        self.image[0:SECTOR_SIZE] = self._read_file(boot_path)

        root_offset = ROOT_START * SECTOR_SIZE
        for entry in self.root_entries:
            self.image[root_offset:root_offset + 32] = entry
            root_offset += 32

        for dirname, sd in self.subdirs.items():
            dir_data = bytearray(SECTOR_SIZE)
            off = 0
            for entry in sd['entries']:
                if off + 32 > SECTOR_SIZE:
                    break
                dir_data[off:off + 32] = entry
                off += 32
            write_cluster_data(self.image, sd['cluster'], bytes(dir_data))

        fat1_offset = FAT_START * SECTOR_SIZE
        self.image[fat1_offset:fat1_offset + len(self.fat)] = self.fat
        fat2_offset = (FAT_START + FAT_SZ) * SECTOR_SIZE
        self.image[fat2_offset:fat2_offset + len(self.fat)] = self.fat

    def _read_file(self, path):
        with open(path, 'rb') as f:
            return f.read()

    def write(self, output_path):
        with open(output_path, 'wb') as f:
            f.write(self.image)


def main():
    global fmt, TOTAL_SECTORS, SEC_PER_CLUS, ROOT_ENT_CNT, FAT_SZ
    global SEC_PER_TRK, NUM_HEADS, IMAGE_SIZE, ROOT_START, ROOT_SECS, DATA_START
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} boot.bin kernel.bin disk.img [file1 ...]",
              file=sys.stderr)
        print("  Optional first argument: --format=1440k or --format=2880k",
              file=sys.stderr)
        print(f"  Files can be: FILE.EXT (root) or DIR/FILE.EXT (subdir)",
              file=sys.stderr)
        sys.exit(1)

    if sys.argv[1].startswith('--format='):
        fmt_name = sys.argv[1].split('=', 1)[1]
        if fmt_name not in FORMATS:
            print(f"Unknown format: {fmt_name}", file=sys.stderr)
            sys.exit(1)
        fmt = FORMATS[fmt_name]
        TOTAL_SECTORS = fmt['total_sectors']
        SEC_PER_CLUS = fmt['sec_per_clus']
        ROOT_ENT_CNT = fmt['root_ent_cnt']
        FAT_SZ = fmt['fat_sz']
        SEC_PER_TRK = fmt['sec_per_trk']
        NUM_HEADS = fmt['num_heads']
        IMAGE_SIZE = SECTOR_SIZE * TOTAL_SECTORS
        ROOT_START = FAT_START + NUM_FATS * FAT_SZ
        ROOT_SECS = (ROOT_ENT_CNT * 32 + BYTES_PER_SEC - 1) // BYTES_PER_SEC
        DATA_START = ROOT_START + ROOT_SECS
        sys.argv.pop(1)

    boot_path = sys.argv[1]
    kernel_path = sys.argv[2]
    output_path = sys.argv[3]
    extra_files = sys.argv[4:]

    with open(boot_path, 'rb') as f:
        boot_data = bytearray(f.read())
    if len(boot_data) != SECTOR_SIZE:
        print(f"Error: boot sector is {len(boot_data)} bytes, expected {SECTOR_SIZE}",
              file=sys.stderr)
        sys.exit(1)
    struct.pack_into('<H', boot_data, 0x0B, BYTES_PER_SEC)
    boot_data[0x0D] = SEC_PER_CLUS
    struct.pack_into('<H', boot_data, 0x0E, RSVD_SEC_CNT)
    boot_data[0x10] = NUM_FATS
    struct.pack_into('<H', boot_data, 0x11, ROOT_ENT_CNT)
    struct.pack_into('<H', boot_data, 0x13, TOTAL_SECTORS if TOTAL_SECTORS <= 0xFFFF else 0)
    boot_data[0x15] = 0xF0
    struct.pack_into('<H', boot_data, 0x16, FAT_SZ)
    struct.pack_into('<H', boot_data, 0x18, SEC_PER_TRK)
    struct.pack_into('<H', boot_data, 0x1A, NUM_HEADS)
    struct.pack_into('<I', boot_data, 0x20, 0 if TOTAL_SECTORS <= 0xFFFF else TOTAL_SECTORS)

    with open(kernel_path, 'rb') as f:
        kernel_data = f.read()

    img = Fat12Image()

    img.image[0:SECTOR_SIZE] = boot_data
    img.add_file_to_root("KERNEL", "SYS", kernel_data)

    for filepath in extra_files:
        dirname = None
        actual_path = filepath
        if ':' in filepath:
            colon_idx = filepath.index(':')
            dirname = filepath[:colon_idx].upper()
            actual_path = filepath[colon_idx + 1:]
        with open(actual_path, 'rb') as f:
            file_data = f.read()
        basename = os.path.basename(actual_path).upper()
        name_parts = basename.split('.')
        name = name_parts[0] if len(name_parts) > 0 else basename
        ext = name_parts[1] if len(name_parts) > 1 else ""

        if dirname:
            img.add_file_to_subdir(dirname, name, ext, file_data)
        else:
            img.add_file_to_root(name, ext, file_data)

    root_offset = ROOT_START * SECTOR_SIZE
    for entry in img.root_entries:
        img.image[root_offset:root_offset + 32] = entry
        root_offset += 32

    for dirname, sd in img.subdirs.items():
        dir_data = bytearray(SECTOR_SIZE)
        off = 0
        for entry in sd['entries']:
            if off + 32 > SECTOR_SIZE:
                break
            dir_data[off:off + 32] = entry
            off += 32
        write_cluster_data(img.image, sd['cluster'], bytes(dir_data))

    fat1_offset = FAT_START * SECTOR_SIZE
    img.image[fat1_offset:fat1_offset + len(img.fat)] = img.fat
    fat2_offset = (FAT_START + FAT_SZ) * SECTOR_SIZE
    img.image[fat2_offset:fat2_offset + len(img.fat)] = img.fat

    with open(output_path, 'wb') as f:
        f.write(img.image)

    kclus = 2
    print(f"Created {output_path}: {IMAGE_SIZE} bytes, "
          f"kernel {len(kernel_data)} bytes in "
          f"{max(1,(len(kernel_data)+(BYTES_PER_SEC * SEC_PER_CLUS)-1)//(BYTES_PER_SEC * SEC_PER_CLUS))} cluster(s) at cluster {kclus}")


if __name__ == '__main__':
    main()
