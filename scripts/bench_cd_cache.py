#!/usr/bin/env python3
import os
import re
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "bench_cd_cache")
IMG = os.path.join(WORKDIR, "bench_cd_cache.img")
ISO = os.path.join(WORKDIR, "bench_cd_cache.iso")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "perfcd.com")
ARCHIVE = os.path.join(WORKDIR, "archive.bin")
TIMEOUT = 20
PHASES = ("CDSAME64", "CDSEQ64", "CDALT2_64", "CDALT4_64")
MAX_CD_READS = {
    "CDSAME64": 1,
    "CDSEQ64": 3,
    "CDALT2_64": 2,
    "CDALT4_64": 4,
}
PERF_RE = re.compile(r"([A-Z0-9]+)=([0-9A-Fa-f]{4})")


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    with open(ARCHIVE, "wb") as f:
        f.write(bytes(((i ^ (i >> 8)) & 0xFF) for i in range(16384)))
    run_cmd(["python3", "scripts/mkiso.py", ISO, f"ARCHIVE.BIN={ARCHIVE}"])
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="PERFCD  COM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        KERNEL,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/perfcd.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, KERNEL, IMG, PROGRAM])


def parse_results(output):
    results = {}
    current_phase = None
    current_ticks = None
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("BENCH: ") and line != "BENCH: PERFCD":
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


def validate_results(results):
    for phase, max_cd in MAX_CD_READS.items():
        cd_reads = results[phase].get("CD", 0)
        if cd_reads > max_cd:
            raise ValueError(f"{phase} fetched too many CD sectors: {cd_reads} > {max_cd}")


def print_summary(results):
    print("\nCD cache benchmark counters:")
    for phase in PHASES:
        counters = results[phase]
        ticks = counters.get("TICKS")
        ticks_text = "?" if ticks is None else str(ticks)
        print(f"{phase}: ticks={ticks_text} cd={counters.get('CD', 0)}")


def main():
    build_artifacts()
    output = run_serial_image(
        IMG,
        TIMEOUT,
        extra_args=("-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on"),
    )
    ok = check_markers(
        output,
        required=(
            "LainDOS booted",
            "BENCH: PERFCD",
            "BENCH: CDSAME64",
            "BENCH: CDSEQ64",
            "BENCH: CDALT2_64",
            "BENCH: CDALT4_64",
            "PASS: PERFCD",
            "Program exited, code=00",
            "HALT",
        ),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="CD cache benchmark QEMU serial output",
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
