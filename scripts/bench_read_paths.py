#!/usr/bin/env python3
import os
import re
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "bench_read_paths")
IMG = os.path.join(WORKDIR, "bench_read_paths.img")
ISO = os.path.join(WORKDIR, "bench_read_paths.iso")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "perfread.com")
READFAT = os.path.join(WORKDIR, "readfat.bin")
LOADBIG = os.path.join(WORKDIR, "loadbig.com")
CDSEQ = os.path.join(WORKDIR, "cdseq.bin")
DIRFILES = os.path.join(WORKDIR, "bigdir")
DIR_FILLER_COUNT = 128
TIMEOUT = 30
PHASES = (
    "READ64",
    "READ512",
    "READ1K",
    "READ4K",
    "EXECLOAD",
    "FATSEEK",
    "FATARCH",
    "DIRLOOK",
    "CDSEQ",
)
PHASE_INFO = {
    "READ64": "bytes=65536 chunk=64",
    "READ512": "bytes=65536 chunk=512",
    "READ1K": "bytes=65536 chunk=1024",
    "READ4K": "bytes=65536 chunk=4096",
    "EXECLOAD": "bytes=49152 load-only",
    "FATSEEK": "reads=32 chunk=512",
    "FATARCH": "reads=32 hot_offsets=4 chunk=512",
    "DIRLOOK": f"dir_entries={DIR_FILLER_COUNT + 1} opens=32 worst-entry",
    "CDSEQ": "bytes=32768 chunk=512",
}
PERF_RE = re.compile(r"([A-Z0-9]+)=([0-9A-Fa-f]{4})")


def pattern_bytes(size):
    return bytes(((i ^ (i >> 8)) & 0xFF) for i in range(size))


def write_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(READFAT, "wb") as f:
        f.write(pattern_bytes(65536))
    load_data = bytearray(pattern_bytes(49152))
    load_data[0] = 0x90
    load_data[1] = 0x90
    with open(LOADBIG, "wb") as f:
        f.write(load_data)
    with open(CDSEQ, "wb") as f:
        f.write(pattern_bytes(32768))
    os.makedirs(DIRFILES, exist_ok=True)
    dir_paths = []
    for index in range(DIR_FILLER_COUNT):
        path = os.path.join(DIRFILES, f"f{index:03d}.dat")
        with open(path, "wb") as f:
            f.write(bytes([index & 0xFF]))
        dir_paths.append(path)
    target = os.path.join(DIRFILES, "target.dat")
    with open(target, "wb") as f:
        f.write(b"T")
    dir_paths.append(target)
    return dir_paths


def build_artifacts():
    dir_paths = write_artifacts()
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"CDSEQ.BIN={CDSEQ}"])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="PERFREADCOM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/perfread.asm", "-o", PROGRAM])
    image_files = [PROGRAM, READFAT, LOADBIG]
    image_files.extend(f"BIGDIR:{path}" for path in dir_paths)
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", BOOT, KERNEL, IMG, *image_files])


def parse_results(output):
    results = {}
    current_phase = None
    current_ticks = None
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("BENCH: ") and line != "BENCH: PERFREAD":
            current_phase = line.split(":", 1)[1].strip()
            current_ticks = None
            continue
        if line.startswith("TICKS="):
            try:
                current_ticks = int(line.split("=", 1)[1], 16)
            except ValueError:
                current_ticks = None
            continue
        if not line.startswith("PERF "):
            continue
        if current_phase is None:
            raise ValueError(f"PERF line without phase: {line}")
        counters = {key: int(value, 16) for key, value in PERF_RE.findall(line)}
        if current_ticks is None:
            raise ValueError(f"PERF line without valid ticks for {current_phase}: {line}")
        counters["TICKS"] = current_ticks
        results[current_phase] = counters
    missing = [phase for phase in PHASES if phase not in results]
    if missing:
        raise ValueError(f"missing benchmark results for: {', '.join(missing)}")
    return results


def require_counter(results, phase, counter):
    if results[phase].get(counter, 0) == 0:
        raise ValueError(f"{phase} did not report a non-zero {counter} counter")


def validate_results(results):
    for phase in ("READ64", "READ512", "READ1K", "READ4K", "EXECLOAD", "FATSEEK", "FATARCH", "DIRLOOK"):
        require_counter(results, phase, "RD")
    for phase in ("READ64", "READ512", "READ1K", "READ4K", "EXECLOAD", "FATSEEK", "FATARCH"):
        require_counter(results, phase, "FW")
    if "LC" not in results["EXECLOAD"]:
        raise ValueError("EXECLOAD did not report an LC loader-copy counter")
    for phase in ("READ64", "READ512", "READ1K", "READ4K"):
        if results[phase].get("RS") != 128:
            raise ValueError(f"{phase} transferred {results[phase].get('RS', 0)} sectors, expected 128")
    for phase in ("READ64", "READ512"):
        if results[phase].get("RD", 0) > 48:
            raise ValueError(f"{phase} did not reduce sequential small-read BIOS calls: RD={results[phase].get('RD', 0)}")
    if results["READ4K"].get("RD", 0) >= results["READ1K"].get("RD", 0):
        raise ValueError("READ4K did not reduce BIOS read calls versus READ1K")
    if results["FATSEEK"].get("RD", 0) > 32:
        raise ValueError(f"FATSEEK regressed random 512-byte reads: RD={results['FATSEEK'].get('RD', 0)}")
    if results["FATSEEK"].get("RS", 0) > 32:
        raise ValueError(f"FATSEEK fetched excess random-read sectors: RS={results['FATSEEK'].get('RS', 0)}")
    if results["FATARCH"].get("FW", 0) >= 100:
        raise ValueError(f"FATARCH did not reduce repeated archive FAT walks: FW={results['FATARCH'].get('FW', 0)}")
    if results["EXECLOAD"].get("RS", 0) != 97:
        raise ValueError(f"EXECLOAD transferred {results['EXECLOAD'].get('RS', 0)} sectors, expected 97")
    if results["EXECLOAD"].get("RD", 0) >= results["EXECLOAD"].get("RS", 0):
        raise ValueError("EXECLOAD did not reduce BIOS read calls versus sectors transferred")
    if results["EXECLOAD"].get("LC", 0) >= results["EXECLOAD"].get("RS", 0):
        raise ValueError("EXECLOAD still bounce-copied every loaded sector")
    require_counter(results, "CDSEQ", "CD")


def print_summary(results):
    print("\nRead-side benchmark counters:")
    for phase in PHASES:
        counters = results[phase]
        print(
            f"{phase}: {PHASE_INFO[phase]} ticks={counters['TICKS']} "
            f"rd={counters.get('RD', 0)} read_sectors={counters.get('RS', 0)} cd={counters.get('CD', 0)} "
            f"loader_copies={counters.get('LC', 0)} fat_walk={counters.get('FW', 0)} fat_alloc_scan={counters.get('FS', 0)} "
            f"fat16_hit={counters.get('FH', 0)} fat16_miss={counters.get('FM', 0)}"
        )


def main():
    build_artifacts()
    output = run_serial_image(
        IMG,
        TIMEOUT,
        drive_opts="if=ide,index=0,media=disk",
        boot_order="c",
        extra_args=("-drive", f"file={ISO},format=raw,if=ide,index=1,media=cdrom,readonly=on"),
    )
    ok = check_markers(
        output,
        required=(
            "LainDOS booted",
            "BENCH: PERFREAD",
            "BENCH: READ64",
            "BENCH: READ512",
            "BENCH: READ1K",
            "BENCH: READ4K",
            "BENCH: EXECLOAD",
            "BENCH: FATSEEK",
            "BENCH: FATARCH",
            "BENCH: DIRLOOK",
            "BENCH: CDSEQ",
            "PASS: PERFREAD",
            "Program exited, code=00",
            "HALT",
        ),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="read-side benchmark QEMU serial output",
    )
    if not ok:
        sys.exit(1)
    try:
        results = parse_results(output)
        validate_results(results)
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        print("--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print_summary(results)


if __name__ == "__main__":
    main()
