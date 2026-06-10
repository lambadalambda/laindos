"""Shared helpers for the Sam & Max Hit the Road CD tests.

Every CD test needs the same three steps: extract the cue/bin pair from the
vendor zip, convert the mode-1/2352 data track to an ISO, and watch the QEMU
serial stream. This module owns those so the per-test scripts only describe
what is unique to them.
"""
import os
import shutil
import sys
import time
import zipfile
from pathlib import Path

from testlib import run_cmd

DEFAULT_ARCHIVE = "vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip"
CUE_NAME = "BG GOLD 3.cue"
BIN_NAME = "BG GOLD 3.bin"
ISO_NAME = "BG_GOLD_3_data.iso"
DEFAULT_FAIL_MARKERS = ("EXC ", "INT 21H AH=", "RUNTIME ERROR 200",
                        "BAD COMMAND OR FILE NAME")


def extract_member(archive, name, output):
    output = Path(output)
    info = archive.getinfo(name)
    if output.exists() and output.stat().st_size == info.file_size:
        return
    with archive.open(info) as src, open(output, "wb") as dst:
        shutil.copyfileobj(src, dst)


def prepare_cd_image(workdir, archive=None):
    """Extract the cue/bin pair into WORKDIR and build the data-track ISO.

    Returns the ISO path (WORKDIR/BG_GOLD_3_data.iso).
    """
    archive_path = str(archive or os.environ.get("LAINDOS_SAMMAX_ARCHIVE",
                                                 DEFAULT_ARCHIVE))
    if not os.path.exists(archive_path):
        print(f"Missing {archive_path}", file=sys.stderr)
        sys.exit(1)
    workdir = Path(workdir)
    workdir.mkdir(parents=True, exist_ok=True)
    cue = workdir / CUE_NAME
    bin_path = workdir / BIN_NAME
    iso = workdir / ISO_NAME
    with zipfile.ZipFile(archive_path) as zf:
        extract_member(zf, CUE_NAME, cue)
        extract_member(zf, BIN_NAME, bin_path)
    run_cmd(["python3", "scripts/extract_mode1_2352.py", str(cue), str(iso)])
    return iso


def output_text(chunks):
    return b"".join(chunks).decode("latin-1", errors="replace")


def wait_for_upper_output(chunks, marker, timeout,
                          fail_markers=DEFAULT_FAIL_MARKERS):
    """Wait for MARKER (case-insensitive) in the serial stream."""
    deadline = time.monotonic() + timeout
    marker = marker.upper()
    while time.monotonic() < deadline:
        output = output_text(chunks).upper()
        if marker in output:
            return True
        if any(m in output for m in fail_markers):
            return False
        time.sleep(0.05)
    return False
