#!/usr/bin/env python3
import os
import shutil
import sys
import tempfile
import time
import zipfile
from pathlib import Path

from sammaxlib import output_text, prepare_cd_image
from testlib import (
    unique_monitor_socket, unique_vnc_arg,
    collect_output, monitor_quit, open_monitor, qemu_binary, qemu_sb16_adlib_silent_args,
    qemu_vga, remove_if_exists, run_cmd, send_monitor_command, start_qemu, stop_qemu,
)

ARCHIVE = "vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip"
BUILDDIR = Path(os.environ.get("LAINDOS_TEST_BUILD_DIR", "build"))
WORKDIR = BUILDDIR / "sammax_cd"
CUE = WORKDIR / "BG GOLD 3.cue"
BIN = WORKDIR / "BG GOLD 3.bin"
ISO = WORKDIR / "BG_GOLD_3_data.iso"
BOOT = WORKDIR / "dig_probe_boot.bin"
KERNEL = WORKDIR / "dig_probe_kernel.bin"
SHELL = WORKDIR / "shell.com"
AUTOEXEC = WORKDIR / "autoexec.bat"
IMG = WORKDIR / "sammax_cd_dig_probe.img"
SERIAL = WORKDIR / "dig_probe_serial.txt"
MONITOR = Path(unique_monitor_socket("sammax-cd-dig-probe"))
TRACE_DOS = os.environ.get("SAMMAX_CD_DIG_TRACE_DOS", "8000")
ICOUNT = os.environ.get("SAMMAX_CD_DIG_ICOUNT", "shift=6")
TIMEOUT = int(os.environ.get("SAMMAX_CD_DIG_TIMEOUT", "90"))


def build_artifacts():
    prepare_cd_image(WORKDIR)
    AUTOEXEC.write_bytes(b"D:\r\nCD \\DEMOS\\DIG\r\nSTART\r\n")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    kernel_cmd = ["nasm", '-DBOOT_FILE="SHELL   COM"']
    if TRACE_DOS:
        kernel_cmd.append(f"-DTRACE_DOS={TRACE_DOS}")
    kernel_cmd.extend(["-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
    run_cmd(kernel_cmd)
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", str(SHELL)])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd160m",
        str(BOOT), str(KERNEL), str(IMG), str(SHELL), str(AUTOEXEC),
    ])


def wait_for_count(chunks, marker, count, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if output_text(chunks).count(marker) >= count:
            return True
        time.sleep(0.05)
    return False


def wait_for_probe_result(chunks, timeout):
    dot_marker = "OPEN .\\imuse.exe"
    progress_marker = "OPEN c:\\lecdemos\\dig\\imuse.ini"
    bad_markers = (
        "Fatal error: Error opening sound engine",
        "DOS/4GW error",
        "Bad command or file name",
        "EXC ",
        "INT 21h AH=",
    )
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = output_text(chunks)
        for marker in bad_markers:
            if marker in output:
                return False, marker
        if dot_marker in output and progress_marker in output:
            return True, progress_marker
        time.sleep(0.05)
    return False, "timeout"


def main():
    build_artifacts()
    remove_if_exists(str(MONITOR))
    cmd = [qemu_binary()]
    if ICOUNT:
        cmd.extend(["-icount", ICOUNT])
    cmd.extend([
        "-drive", f"file={IMG},format=raw,if=ide,index=0,media=disk",
        "-drive", f"file={ISO},format=raw,if=ide,index=1,media=cdrom,readonly=on",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
        *qemu_sb16_adlib_silent_args(),
    ])
    proc, stdout_chunks, stderr_chunks, threads = start_qemu(cmd)
    sock = None
    try:
        sock = open_monitor(str(MONITOR), timeout=10)
        prompt = "Press any key to continue"
        if not wait_for_count(stdout_chunks, "OPEN START.BAT", 1, 30):
            print("FAIL: START.BAT did not run")
            sys.exit(1)
        send_monitor_command(sock, "sendkey spc")
        if not wait_for_count(stdout_chunks, prompt, 1, 75):
            print("FAIL: DIG.BAT pause did not appear")
            sys.exit(1)
        send_monitor_command(sock, "sendkey spc")
        ok, marker = wait_for_probe_result(stdout_chunks, TIMEOUT)
        if ok:
            print(f"  PASS: reached '{marker}'")
        else:
            print(f"FAIL: DIG probe stopped at {marker}")
            sys.exit(1)
    finally:
        if sock is not None:
            try:
                monitor_quit(sock, proc)
            except Exception:
                pass
            try:
                sock.close()
            except Exception:
                pass
        stop_qemu(proc)
        output = collect_output(stdout_chunks, stderr_chunks, threads)
        SERIAL.write_text(output, encoding="utf-8")
    print(f"Serial saved to {SERIAL}")
    print("\nSam & Max CD DIG probe passed.")


if __name__ == "__main__":
    main()
