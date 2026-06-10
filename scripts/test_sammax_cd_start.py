#!/usr/bin/env python3
import os
import shutil
import sys
import tempfile
import time
import zipfile
from pathlib import Path
from sammaxlib import prepare_cd_image
from testlib import (
    unique_monitor_socket, unique_vnc_arg,
    check_markers,
    collect_output,
    framebuffer_active,
    monitor_quit,
    monitor_screendump,
    open_monitor,
    qemu_sb16_silent_args,
    qemu_vga,
    remove_if_exists,
    run_cmd,
    send_monitor_key,
    start_qemu,
    stop_qemu,
    wait_for_output,
)

ARCHIVE = "vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip"
BUILDDIR = Path(os.environ.get("LAINDOS_TEST_BUILD_DIR", "build"))
WORKDIR = BUILDDIR / "sammax_cd"
CUE = WORKDIR / "BG GOLD 3.cue"
BIN = WORKDIR / "BG GOLD 3.bin"
ISO = WORKDIR / "BG_GOLD_3_data.iso"
BOOT = WORKDIR / "sammax_start_boot.bin"
KERNEL = WORKDIR / "sammax_start_kernel.bin"
SHELL = WORKDIR / "shell.com"
AUTOEXEC = WORKDIR / "autoexec.bat"
IMG = WORKDIR / "sammax_cd_start.img"
MONITOR = Path(unique_monitor_socket("sammax-cd-start"))
SCREENSHOT = BUILDDIR / "sammax_cd_start_screen.ppm"
TIMEOUT = int(os.environ.get("SAMMAX_CD_START_TIMEOUT", "50"))


def build_artifacts():
    prepare_cd_image(WORKDIR)
    AUTOEXEC.write_bytes(b"D:\r\nCD \\SAMNMAX\r\nSAMNMAX\r\nEXIT\r\n")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", str(SHELL)])
    run_cmd(["python3", "scripts/mkimage.py", str(BOOT), str(KERNEL), str(IMG), str(SHELL), str(AUTOEXEC)])


def run_qemu():
    remove_if_exists(str(MONITOR))
    remove_if_exists(str(SCREENSHOT))
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        "qemu-system-i386",
        "-drive", f"file={IMG},format=raw,if=floppy",
        "-drive", f"file={ISO},format=raw,if=ide,media=cdrom,readonly=on",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
        *qemu_sb16_silent_args(),
    ])
    sock = None
    prompt_ok = False
    try:
        sock = open_monitor(str(MONITOR), timeout=10)
        prompt_ok = wait_for_output(stdout_chunks, "Press Enter", timeout=TIMEOUT, stop_markers=("EXC ", "INT 21h AH="))
        if prompt_ok:
            send_monitor_key(sock, "ret", delay=8.0)
            time.sleep(12)
        monitor_screendump(sock, str(SCREENSHOT), delay=1)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), prompt_ok


def main():
    build_artifacts()
    output, prompt_ok = run_qemu()
    failed = False
    if not prompt_ok:
        print("  FAIL: timed out waiting for Sam & Max prompt")
        failed = True
    failed = not check_markers(
        output,
        required=("DOS/4GW Protected Mode Run-time", "Sound drivers failed to initialize"),
        forbidden=("EXC ", "INT 21h AH=", "Bad command", "No such file", "Not enough memory"),
        output_label="Sam & Max CD startup serial output",
        dump_on_failure=False,
    ) or failed
    failed = not framebuffer_active(SCREENSHOT, "Sam & Max framebuffer", min_colors=4, min_nonblack=1000) or failed
    if failed:
        print("\n--- Sam & Max CD startup serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nSam & Max CD startup smoke passed.")


if __name__ == "__main__":
    main()
