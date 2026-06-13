#!/usr/bin/env python3
import os
import re
import sys

from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "bench_metadata")
TIMEOUT = 25
PHASES = ("TIMECOMMIT", "CLEANCOMMIT", "CLEANCLOSE", "OVERWRITE", "TEMPRENAME", "DELETEOLD", "SUBDIRTIME")
PERF_RE = re.compile(r"([A-Z0-9]+)=([0-9A-Fa-f]{4})")
FAT16_CEILINGS = {
    "TIMECOMMIT": {"DIR": 32, "WR": 35, "WD": 1},
    "CLEANCOMMIT": {"DIR": 0, "WR": 0, "WD": 0},
    "CLEANCLOSE": {"DIR": 0, "WR": 0, "WD": 0},
    "OVERWRITE": {"DIR": 0, "WR": 1, "WD": 1},
    "TEMPRENAME": {"DIR": 3, "WR": 6, "WD": 1},
    "DELETEOLD": {"DIR": 1, "WR": 3, "WD": 0},
    "SUBDIRTIME": {"DIR": 32, "WR": 35, "WD": 1},
}
FAT12_CEILINGS = {
    "TIMECOMMIT": {"DIR": 32, "WR": 64, "WD": 1},
    "CLEANCOMMIT": {"DIR": 0, "WR": 0, "WD": 0},
    "CLEANCLOSE": {"DIR": 0, "WR": 0, "WD": 0},
    "OVERWRITE": {"DIR": 0, "WR": 1, "WD": 1},
    "TEMPRENAME": {"DIR": 3, "WR": 32, "WD": 1},
    "DELETEOLD": {"DIR": 1, "WR": 20, "WD": 0},
    "SUBDIRTIME": {"DIR": 32, "WR": 64, "WD": 1},
}
CONFIGS = (
    {
        "name": "FAT16",
        "boot_define": "-DFAT16=1",
        "mkimage_args": ("--format=hd96m",),
        "drive_opts": "if=ide,index=0,media=disk",
        "boot_order": "c",
        "ceilings": FAT16_CEILINGS,
    },
    {
        "name": "FAT12",
        "boot_define": "-DFAT12=1",
        "mkimage_args": ("--format=hd10m",),
        "drive_opts": "if=ide,index=0,media=disk",
        "boot_order": "c",
        "ceilings": FAT12_CEILINGS,
    },
)


def build_image(config):
    workdir = os.path.join(WORKDIR, config["name"].lower())
    os.makedirs(workdir, exist_ok=True)
    img = os.path.join(workdir, "bench_metadata.img")
    boot = os.path.join(workdir, "boot.bin")
    kernel = os.path.join(workdir, "kernel.bin")
    program = os.path.join(workdir, "perfmeta.com")
    run_cmd(["nasm", config["boot_define"], "-f", "bin", "src/boot.asm", "-o", boot])
    run_cmd([
        "nasm",
        '-DBOOT_FILE="PERFMETACOM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        kernel,
    ])
    run_cmd(["nasm", "-f", "bin", "tests/programs/perfmeta.asm", "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", *config["mkimage_args"], boot, kernel, img, program])
    return img


def parse_results(output):
    results = {}
    current_phase = None
    current_ticks = None
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if line.startswith("BENCH: ") and line != "BENCH: PERFMETA":
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


def validate_results(results, ceilings):
    for phase in PHASES:
        if "DIR" not in results[phase] or "WR" not in results[phase]:
            raise ValueError(f"{phase} did not report DIR/WR counters")
    for phase, limits in ceilings.items():
        for key, limit in limits.items():
            value = results[phase].get(key, 0)
            if value > limit:
                raise ValueError(f"{phase} {key}={value} exceeds ceiling {limit}")


def print_summary(name, results):
    print(f"\n{name} metadata benchmark counters:")
    for phase in PHASES:
        counters = results[phase]
        ticks = counters.get("TICKS")
        ticks_text = "?" if ticks is None else str(ticks)
        print(
            f"{phase}: ticks={ticks_text} "
            f"rd={counters.get('RD', 0)} wr={counters.get('WR', 0)} data_wr={counters.get('WD', 0)} "
            f"fat_flush={counters.get('FF', 0)} fat16_flush={counters.get('F16', 0)} "
            f"dir_flush={counters.get('DIR', 0)} write_calls={counters.get('WFC', 0)}"
        )


def main():
    for config in CONFIGS:
        img = build_image(config)
        output = run_serial_image(
            img,
            TIMEOUT,
            drive_opts=config["drive_opts"],
            boot_order=config["boot_order"],
        )
        ok = check_markers(
            output,
            required=(
                "LainDOS booted",
                "BENCH: PERFMETA",
                "BENCH: TIMECOMMIT",
                "BENCH: CLEANCOMMIT",
                "BENCH: CLEANCLOSE",
                "BENCH: OVERWRITE",
                "BENCH: TEMPRENAME",
                "BENCH: DELETEOLD",
                "BENCH: SUBDIRTIME",
                "PASS: PERFMETA",
                "Program exited, code=00",
                "HALT",
            ),
            forbidden=("FAIL:", "EXC ", "INT 21h AH="),
            output_label=f"{config['name']} metadata benchmark QEMU serial output",
        )
        if not ok:
            sys.exit(1)
        try:
            results = parse_results(output)
            validate_results(results, config["ceilings"])
        except ValueError as exc:
            print(f"FAIL: {config['name']}: {exc}", file=sys.stderr)
            print("--- QEMU serial output ---")
            print(output)
            print("--- end ---")
            sys.exit(1)
        print_summary(config["name"], results)


if __name__ == "__main__":
    main()
