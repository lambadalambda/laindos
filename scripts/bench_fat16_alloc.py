#!/usr/bin/env python3
import os
import re
import shutil
import struct
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "bench_fat16_alloc")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "perffat.com")
BASE_IMG = os.path.join(WORKDIR, "base.img")
TIMEOUT = 30
MAX_FAT_SCAN_STEPS = 512
PERF_RE = re.compile(r"([A-Z0-9]+)=([0-9A-Fa-f]{4})")
SCENARIOS = ("sequential", "fragmented", "highcluster", "nearlyfull")


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="PERFFAT COM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/perffat.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", BOOT, KERNEL, BASE_IMG, PROGRAM])


def image_geometry(image):
    bps = struct.unpack_from("<H", image, 11)[0]
    spc = image[13]
    reserved = struct.unpack_from("<H", image, 14)[0]
    fats = image[16]
    root_entries = struct.unpack_from("<H", image, 17)[0]
    fat_secs = struct.unpack_from("<H", image, 22)[0]
    total = struct.unpack_from("<H", image, 19)[0]
    if total == 0:
        total = struct.unpack_from("<I", image, 32)[0]
    root_secs = (root_entries * 32 + bps - 1) // bps
    fat_start = reserved * bps
    root_start = (reserved + fats * fat_secs) * bps
    data_start_sec = reserved + fats * fat_secs + root_secs
    data_clusters = (total - data_start_sec) // spc
    return {
        "bps": bps,
        "spc": spc,
        "fats": fats,
        "fat_secs": fat_secs,
        "fat_start": fat_start,
        "root_start": root_start,
        "root_entries": root_entries,
        "last_cluster": data_clusters + 1,
    }


def fat16_get(image, geo, cluster):
    return struct.unpack_from("<H", image, geo["fat_start"] + cluster * 2)[0]


def fat16_set_all(image, geo, cluster, value):
    for copy in range(geo["fats"]):
        off = geo["fat_start"] + copy * geo["fat_secs"] * geo["bps"] + cluster * 2
        struct.pack_into("<H", image, off, value & 0xFFFF)


def used_cluster_high_water(image, geo):
    high = 1
    root_end = geo["root_start"] + geo["root_entries"] * 32
    for off in range(geo["root_start"], root_end, 32):
        entry = image[off:off + 32]
        if entry[0] == 0:
            break
        if entry[0] == 0xE5 or entry[11] == 0x0F:
            continue
        cluster = struct.unpack_from("<H", entry, 26)[0]
        seen = set()
        while 2 <= cluster <= geo["last_cluster"] and cluster not in seen:
            seen.add(cluster)
            high = max(high, cluster)
            nxt = fat16_get(image, geo, cluster)
            if nxt >= 0xFFF8:
                break
            cluster = nxt
    return high


def mark_used_range(image, geo, first, last):
    first = max(2, first)
    last = min(last, geo["last_cluster"])
    for cluster in range(first, last + 1):
        if fat16_get(image, geo, cluster) == 0:
            fat16_set_all(image, geo, cluster, 0xFFFF)


def shape_image(path, scenario):
    if scenario == "sequential":
        return
    with open(path, "rb") as f:
        image = bytearray(f.read())
    geo = image_geometry(image)
    first_extra = used_cluster_high_water(image, geo) + 1
    if scenario == "fragmented":
        for cluster in range(first_extra, min(first_extra + 192, geo["last_cluster"] + 1), 2):
            fat16_set_all(image, geo, cluster, 0xFFFF)
    elif scenario == "highcluster":
        target = min(8192, geo["last_cluster"] - 64)
        mark_used_range(image, geo, first_extra, target - 1)
    elif scenario == "nearlyfull":
        mark_used_range(image, geo, first_extra, geo["last_cluster"] - 40)
    else:
        raise ValueError(f"unknown scenario: {scenario}")
    with open(path, "wb") as f:
        f.write(image)


def parse_result(output):
    current_ticks = None
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("TICKS="):
            try:
                current_ticks = int(line.split("=", 1)[1], 16)
            except ValueError:
                current_ticks = None
            continue
        if line.startswith("PERF "):
            counters = {key: int(value, 16) for key, value in PERF_RE.findall(line)}
            counters["TICKS"] = current_ticks
            return counters
    raise ValueError("missing PERF line")


def run_scenario(scenario):
    img = os.path.join(WORKDIR, f"{scenario}.img")
    shutil.copyfile(BASE_IMG, img)
    shape_image(img, scenario)
    output = run_serial_image(img, TIMEOUT, drive_opts="if=ide,index=0,media=disk", boot_order="c")
    ok = check_markers(
        output,
        required=(
            "LainDOS booted",
            "BENCH: PERFAT",
            "BENCH: ALLOC",
            "PASS: PERFAT",
            "Program exited, code=00",
            "HALT",
        ),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label=f"FAT16 allocation benchmark {scenario} QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    try:
        return parse_result(output)
    except ValueError as exc:
        print(f"FAIL: {scenario}: {exc}", file=sys.stderr)
        print("--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)


def validate_results(results):
    for scenario, counters in results.items():
        for key in ("FA", "FS", "FM", "MW"):
            if counters.get(key, 0) == 0:
                raise ValueError(f"{scenario} did not report a non-zero {key} counter")
        if counters.get("FS", 0) > MAX_FAT_SCAN_STEPS:
            raise ValueError(
                f"{scenario} scanned too many FAT entries: "
                f"{counters.get('FS', 0)} > {MAX_FAT_SCAN_STEPS}"
            )


def print_summary(results):
    print("\nFAT16 allocation benchmark counters:")
    for scenario in SCENARIOS:
        counters = results[scenario]
        ticks = counters.get("TICKS")
        ticks_text = "?" if ticks is None else str(ticks)
        print(
            f"{scenario}: ticks={ticks_text} "
            f"rd={counters.get('RD', 0)} wr={counters.get('WR', 0)} "
            f"fat_alloc={counters.get('FA', 0)} fat_scan={counters.get('FS', 0)} "
            f"fat16_hit={counters.get('FH', 0)} fat16_miss={counters.get('FM', 0)} "
            f"fat16_flush={counters.get('F16', 0)} mirror_writes={counters.get('MW', 0)}"
        )


def main():
    build_artifacts()
    results = {scenario: run_scenario(scenario) for scenario in SCENARIOS}
    try:
        validate_results(results)
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
    print_summary(results)


if __name__ == "__main__":
    main()
