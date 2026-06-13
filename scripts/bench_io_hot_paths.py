#!/usr/bin/env python3
import os
import re
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "bench_io_hot_paths")
IMG = os.path.join(WORKDIR, "bench_io_hot_paths.img")
ISO = os.path.join(WORKDIR, "bench_io_hot_paths.iso")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "perfio.com")
MIX = os.path.join(WORKDIR, "mix.bin")
TIMEOUT = 25
MAX_DRIVESW_READS = 128

PHASES = (
    "WRITE512",
    "WRITE128",
    "DRIVESW",
    "FAT16ALLOC",
    "METADATA",
    "CDMIX64",
)
PERF_RE = re.compile(r"([A-Z0-9]+)=([0-9A-Fa-f]{4})")


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(MIX, "wb") as f:
        f.write(bytes(((i ^ (i >> 8)) & 0xFF) for i in range(8192)))
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"MIX.BIN={MIX}"])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="PERFIO  COM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/perfio.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", BOOT, KERNEL, IMG, PROGRAM])


def parse_results(output):
    results = {}
    current_phase = None
    current_ticks = None
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("BENCH: ") and line != "BENCH: PERFIO":
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
    require_counter(results, "WRITE512", "WR")
    require_counter(results, "WRITE512", "WD")
    require_counter(results, "WRITE128", "WFC")
    require_counter(results, "WRITE128", "WD")
    require_counter(results, "DRIVESW", "DSW")
    require_counter(results, "DRIVESW", "CD")
    require_counter(results, "DRIVESW", "RD")
    if results["DRIVESW"].get("RD", 0) > MAX_DRIVESW_READS:
        raise ValueError(
            f"DRIVESW reloaded too many hard-disk sectors: "
            f"{results['DRIVESW'].get('RD', 0)} > {MAX_DRIVESW_READS}"
        )
    require_counter(results, "FAT16ALLOC", "FA")
    require_counter(results, "METADATA", "DIR")
    require_counter(results, "CDMIX64", "CD")


def print_summary(results):
    print("\nI/O hot-path benchmark counters:")
    for phase in PHASES:
        counters = results[phase]
        ticks = counters.get("TICKS")
        ticks_text = "?" if ticks is None else str(ticks)
        print(
            f"{phase}: ticks={ticks_text} "
            f"rd={counters.get('RD', 0)} wr={counters.get('WR', 0)} data_wr={counters.get('WD', 0)} "
            f"cd={counters.get('CD', 0)} "
            f"drive_switches={counters.get('DSW', 0)} fat_flush={counters.get('FF', 0)} "
            f"fat16_flush={counters.get('F16', 0)} fat_alloc={counters.get('FA', 0)} "
            f"fat_scan={counters.get('FS', 0)} fat16_hit={counters.get('FH', 0)} "
            f"fat16_miss={counters.get('FM', 0)} mirror_writes={counters.get('MW', 0)} "
            f"dir_flush={counters.get('DIR', 0)} write_calls={counters.get('WFC', 0)} "
            f"prereads={counters.get('WFP', 0)}"
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
            "BENCH: PERFIO",
            "BENCH: WRITE512",
            "BENCH: WRITE128",
            "BENCH: DRIVESW",
            "BENCH: FAT16ALLOC",
            "BENCH: METADATA",
            "BENCH: CDMIX64",
            "PASS: PERFIO",
            "Program exited, code=00",
            "HALT",
        ),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="I/O hot-path benchmark QEMU serial output",
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
