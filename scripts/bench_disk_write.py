#!/usr/bin/env python3
import os
import re
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
IMG = os.path.join(BUILDDIR, "bench_disk_write.img")
BOOT = os.path.join(BUILDDIR, "bench_disk_write_boot.bin")
KERNEL = os.path.join(BUILDDIR, "bench_disk_write_kernel.bin")
PROGRAM = os.path.join(BUILDDIR, "perfwr.com")
TIMEOUT = 20

PHASES = ("WRITE512", "WRITE128", "WRITE64")
PERF_RE = re.compile(r"([A-Z0-9]+)=([0-9A-Fa-f]{4})")


def build_image():
    os.makedirs(BUILDDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="PERFWR  COM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/perfwrite.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd96m", BOOT, KERNEL, IMG, PROGRAM])


def parse_results(output):
    results = {}
    current_phase = None
    current_ticks = None
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("BENCH: WRITE"):
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
    require_counter(results, "WRITE512", "WD")
    require_counter(results, "WRITE128", "WFC")
    require_counter(results, "WRITE128", "WD")
    require_counter(results, "WRITE64", "WFC")
    require_counter(results, "WRITE64", "WD")
    full_sector_writes = results["WRITE512"].get("WR", 0)
    for phase in ("WRITE128", "WRITE64"):
        if results[phase].get("WR", 0) > full_sector_writes:
            raise ValueError(
                f"{phase} physical writes exceeded WRITE512 "
                f"({results[phase].get('WR', 0)} > {full_sector_writes})"
            )


def print_summary(results):
    print("\nDisk write benchmark counters:")
    for phase in PHASES:
        counters = results[phase]
        ticks = counters.get("TICKS")
        ticks_text = "?" if ticks is None else str(ticks)
        print(
            f"{phase}: ticks={ticks_text} "
            f"rd={counters.get('RD', 0)} wr={counters.get('WR', 0)} data_wr={counters.get('WD', 0)} "
            f"fat_flush={counters.get('FF', 0)} fat16_flush={counters.get('F16', 0)} "
            f"dir_flush={counters.get('DIR', 0)} write_calls={counters.get('WFC', 0)} "
            f"prereads={counters.get('WFP', 0)} drive_switches={counters.get('DSW', 0)}"
        )


def main():
    build_image()
    output = run_serial_image(IMG, TIMEOUT, drive_opts="", boot_order="c")
    ok = check_markers(
        output,
        required=(
            "LainDOS booted",
            "BENCH: PERFWRITE",
            "BENCH: WRITE512",
            "BENCH: WRITE128",
            "BENCH: WRITE64",
            "BENCH: READBEFORECLOSE",
            "PASS: PERFWRITE",
            "Program exited, code=00",
            "HALT",
        ),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="disk-write benchmark QEMU serial output",
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
