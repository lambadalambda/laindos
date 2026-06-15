#!/usr/bin/env python3
import os
import re
import sys

from fatlib import FatImage
from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "subdir_cache")
BOOT = os.path.join(WORKDIR, "boot.bin")
BOOT16 = os.path.join(WORKDIR, "boot16.bin")
DIRCACHE_KERNEL = os.path.join(WORKDIR, "dircache_kernel.bin")
DIRCFAIL_KERNEL = os.path.join(WORKDIR, "dircfail_kernel.bin")
DIRCDRV_KERNEL = os.path.join(WORKDIR, "dircdrv_kernel.bin")
DIRCACHE_COM = os.path.join(WORKDIR, "dircache.com")
DIRCFAIL_COM = os.path.join(WORKDIR, "dircfail.com")
DIRCDRV_COM = os.path.join(WORKDIR, "dircdrv.com")
DIRCACHE_IMG = os.path.join(WORKDIR, "dircache.img")
DIRCFAIL_IMG = os.path.join(WORKDIR, "dircfail.img")
DIRCDRV_FLOPPY_IMG = os.path.join(WORKDIR, "dircdrv_floppy.img")
DIRCDRV_HD_IMG = os.path.join(WORKDIR, "dircdrv_hd.img")
FIXTURE_DIR = os.path.join(WORKDIR, "fixtures")
TIMEOUT = 12
FILLER_COUNT = 128
PERF_RE = re.compile(r"([A-Z0-9]+)=([0-9A-Fa-f]{4})")


def write_fixtures():
    os.makedirs(FIXTURE_DIR, exist_ok=True)
    paths = []
    for index in range(FILLER_COUNT):
        path = os.path.join(FIXTURE_DIR, f"f{index:03d}.dat")
        with open(path, "wb") as f:
            f.write(bytes([index & 0xFF]))
        paths.append(path)
    target = os.path.join(FIXTURE_DIR, "target.dat")
    with open(target, "wb") as f:
        f.write(b"target\n")
    paths.append(target)
    aonly = os.path.join(FIXTURE_DIR, "aonly.dat")
    with open(aonly, "wb") as f:
        f.write(b"A-only\n")
    paths.append(aonly)
    return [f"CACHE:{path}" for path in paths]


def build_common():
    os.makedirs(WORKDIR, exist_ok=True)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT16])
    extra_files = write_fixtures()
    run_cmd(["nasm", "-f", "bin", "tests/programs/dircache.asm", "-o", DIRCACHE_COM])
    run_cmd(["nasm", "-f", "bin", "tests/programs/dircfail.asm", "-o", DIRCFAIL_COM])
    run_cmd(["nasm", "-f", "bin", "tests/programs/dircdrv.asm", "-o", DIRCDRV_COM])
    return extra_files


def build_dircache(extra_files):
    run_cmd([
        "nasm",
        '-DBOOT_FILE="DIRCACHECOM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        DIRCACHE_KERNEL,
    ])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, DIRCACHE_KERNEL, DIRCACHE_IMG, DIRCACHE_COM, *extra_files])


def build_dircfail(extra_files):
    run_cmd([
        "nasm",
        '-DBOOT_FILE="DIRCFAILCOM"',
        "-DTEST_FLUSH_DIR_SLOT_FAIL",
        "-DTEST_FLUSH_DIR_SLOT_FAIL_AFTER=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        DIRCFAIL_KERNEL,
    ])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, DIRCFAIL_KERNEL, DIRCFAIL_IMG, DIRCFAIL_COM, *extra_files])


def build_dircdrv(extra_files):
    conly = os.path.join(FIXTURE_DIR, "conly.dat")
    with open(conly, "wb") as f:
        f.write(b"C-only\n")
    run_cmd([
        "nasm",
        '-DBOOT_FILE="DIRCDRV COM"',
        "-DPERF_IO_COUNTS=1",
        "-f",
        "bin",
        "src/kernel.asm",
        "-o",
        DIRCDRV_KERNEL,
    ])
    run_cmd(["python3", "scripts/mkimage.py", BOOT, DIRCDRV_KERNEL, DIRCDRV_FLOPPY_IMG, DIRCDRV_COM, *extra_files])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd10m", BOOT16, DIRCDRV_KERNEL, DIRCDRV_HD_IMG, f"CACHE:{conly}"])


def parse_perf(output):
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("PERF "):
            return {key: int(value, 16) for key, value in PERF_RE.findall(line)}
    raise ValueError("missing PERF line")


def run_dircache():
    output = run_serial_image(DIRCACHE_IMG, TIMEOUT)
    ok = check_markers(
        output,
        required=("BENCH: DIRCACHE", "PASS: DIRCACHE", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="subdir cache QEMU serial output",
    )
    try:
        counters = parse_perf(output)
        hits = counters.get("DCH", 0)
        misses = counters.get("DCM", 0)
        reads = counters.get("RD", 0)
        if hits == 0:
            raise ValueError("subdirectory cache reported no hits")
        if misses == 0:
            raise ValueError("subdirectory cache reported no misses")
        if reads > 16:
            raise ValueError(f"subdirectory cache did not reduce repeated lookup reads: RD={reads}")
        print(f"  PASS: subdirectory cache counters rd={reads} hits={hits} misses={misses}")
    except ValueError as exc:
        print(f"  FAIL: {exc}")
        ok = False
    if not ok:
        print("\n--- subdir cache serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)


def run_dircfail():
    output = run_serial_image(DIRCFAIL_IMG, TIMEOUT)
    ok = check_markers(
        output,
        required=("PASS: DIRCFFAIL", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="subdir cache failed-flush QEMU serial output",
    )
    img = FatImage.from_file(DIRCFAIL_IMG)
    if img.find("CACHE/BADFAIL.DAT") is not None:
        print("  FAIL: BADFAIL.DAT appeared after failed directory flush")
        ok = False
    if img.find("CACHE/GOOD.DAT") is None:
        print("  FAIL: GOOD.DAT missing after retry")
        ok = False
    else:
        print("  PASS: failed directory flush did not poison subdirectory cache")
    if not ok:
        print("\n--- subdir cache failed-flush serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)


def run_dircdrv():
    output = run_serial_image(
        DIRCDRV_FLOPPY_IMG,
        TIMEOUT,
        extra_args=("-drive", f"file={DIRCDRV_HD_IMG},format=raw,if=ide,index=0,media=disk"),
    )
    ok = check_markers(
        output,
        required=("BENCH: DIRCDRV", "PASS: DIRCDRV", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "EXC ", "INT 21h AH="),
        output_label="subdir cache drive-switch QEMU serial output",
    )
    try:
        counters = parse_perf(output)
        hits = counters.get("DCH", 0)
        misses = counters.get("DCM", 0)
        if hits < 3:
            raise ValueError(f"drive-switch probe had too few cache hits: DCH={hits}")
        if misses < 3:
            raise ValueError(f"drive-switch probe did not invalidate on switches: DCM={misses}")
        print(f"  PASS: drive-switch cache counters hits={hits} misses={misses}")
    except ValueError as exc:
        print(f"  FAIL: {exc}")
        ok = False
    if not ok:
        print("\n--- subdir cache drive-switch serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)


def main():
    extra_files = build_common()
    build_dircache(extra_files)
    run_dircache()
    build_dircfail(extra_files)
    run_dircfail()
    build_dircdrv(extra_files)
    run_dircdrv()
    print("\nSubdirectory cache regression test passed.")


if __name__ == "__main__":
    main()
