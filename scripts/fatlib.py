"""Shared FAT12/16 image reader for test and build scripts.

One BPB parser, FAT-entry reader, chain reader, and directory helpers so
scripts stop growing private copies with diverging end-of-chain constants.
End-of-chain is >= 0xFF8 (FAT12) / 0xFFF8 (FAT16); reserved and bad-cluster
values terminate a chain walk the same way corrupt links do (the cycle guard
stops repeats).
"""
import struct

EOC12 = 0xFF8
EOC16 = 0xFFF8
ATTR_READONLY = 0x01
ATTR_HIDDEN = 0x02
ATTR_SYSTEM = 0x04
ATTR_VOLUME = 0x08
ATTR_DIR = 0x10
ATTR_ARCHIVE = 0x20
ATTR_LFN = 0x0F


class FatImage:
    def __init__(self, data, offset=0, fat_index=0):
        self.data = data
        self.offset = offset
        self.bps = struct.unpack_from("<H", data, offset + 11)[0]
        self.spc = data[offset + 13]
        self.reserved = struct.unpack_from("<H", data, offset + 14)[0]
        self.fat_count = data[offset + 16]
        self.root_entries = struct.unpack_from("<H", data, offset + 17)[0]
        total16 = struct.unpack_from("<H", data, offset + 19)[0]
        self.total_sectors = total16 or struct.unpack_from("<I", data, offset + 32)[0]
        self.sectors_per_fat = struct.unpack_from("<H", data, offset + 22)[0]
        self.root_sectors = (self.root_entries * 32 + self.bps - 1) // self.bps
        self.fat_off = offset + (self.reserved + fat_index * self.sectors_per_fat) * self.bps
        root_sector = self.reserved + self.fat_count * self.sectors_per_fat
        self.root_off = offset + root_sector * self.bps
        self.data_off = self.root_off + self.root_sectors * self.bps
        data_sectors = self.total_sectors - root_sector - self.root_sectors
        self.bits = 12 if data_sectors // self.spc < 4085 else 16
        self.eoc = EOC16 if self.bits == 16 else EOC12

    @classmethod
    def from_file(cls, path, offset=0, fat_index=0):
        with open(path, "rb") as f:
            return cls(f.read(), offset, fat_index)

    def fat_next(self, cluster):
        if self.bits == 16:
            return struct.unpack_from("<H", self.data, self.fat_off + cluster * 2)[0]
        off = self.fat_off + cluster + cluster // 2
        value = self.data[off] | (self.data[off + 1] << 8)
        return value >> 4 if cluster & 1 else value & 0x0FFF

    def cluster_chain(self, cluster):
        chain = []
        seen = set()
        while 2 <= cluster < self.eoc and cluster not in seen:
            seen.add(cluster)
            chain.append(cluster)
            cluster = self.fat_next(cluster)
        return chain

    def cluster_off(self, cluster):
        return self.data_off + (cluster - 2) * self.bps * self.spc

    def read_chain(self, cluster, size=None):
        cluster_bytes = self.bps * self.spc
        blob = b"".join(
            bytes(self.data[self.cluster_off(c):self.cluster_off(c) + cluster_bytes])
            for c in self.cluster_chain(cluster))
        return blob if size is None else blob[:size]

    def root_dir(self):
        return bytes(self.data[self.root_off:self.root_off + self.root_entries * 32])

    def read_dir(self, entry):
        """Directory contents for a directory entry (or the root for None)."""
        if entry is None:
            return self.root_dir()
        return self.read_chain(entry_cluster(entry))

    def find(self, path):
        """Walk PATH ("DIR/SUB/FILE.EXT", case-insensitive) from the root.

        Returns the 32-byte directory entry, or None.
        """
        directory = self.root_dir()
        entry = None
        for part in path.replace("\\", "/").split("/"):
            if not part:
                continue
            entry = find_entry(directory, part)
            if entry is None:
                return None
            directory = self.read_chain(entry_cluster(entry))
        return entry

    def read_file(self, path):
        entry = self.find(path)
        if entry is None:
            raise FileNotFoundError(path)
        return self.read_chain(entry_cluster(entry), entry_size(entry))


def name83(name):
    """\"FILE.EXT\" -> 11-byte padded directory-entry name."""
    name = name.upper()
    if name in (".", ".."):
        return name.ljust(11).encode("ascii")
    if "." in name:
        stem, ext = name.rsplit(".", 1)
    else:
        stem, ext = name, ""
    return (stem.ljust(8) + ext.ljust(3)).encode("ascii")


def entry_name(entry):
    stem = entry[:8].decode("ascii", errors="replace").rstrip()
    ext = entry[8:11].decode("ascii", errors="replace").rstrip()
    return stem + (f".{ext}" if ext else "")


def entry_attr(entry):
    return entry[11]


def entry_cluster(entry):
    return struct.unpack_from("<H", entry, 26)[0]


def entry_size(entry):
    return struct.unpack_from("<I", entry, 28)[0]


def iter_dir(dir_data, include_deleted=False):
    """Yield (offset, entry) for in-use entries; stops at the end marker."""
    for off in range(0, len(dir_data) - 31, 32):
        entry = bytes(dir_data[off:off + 32])
        if entry[0] == 0:
            break
        if entry[0] == 0xE5 and not include_deleted:
            continue
        if entry_attr(entry) == ATTR_LFN:
            continue
        yield off, entry


def find_entry(dir_data, name):
    """Find NAME ("FILE.EXT" form or raw 11 bytes) in directory bytes."""
    raw = bytes(name) if isinstance(name, (bytes, bytearray)) else name83(name)
    for _, entry in iter_dir(dir_data):
        if entry[:11] == raw:
            return entry
    return None


def find_entry_offset(dir_data, name):
    raw = bytes(name) if isinstance(name, (bytes, bytearray)) else name83(name)
    for off, entry in iter_dir(dir_data):
        if entry[:11] == raw:
            return off
    return None
