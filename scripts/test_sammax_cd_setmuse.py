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
    read_text_screen,
    check_markers,
    collect_output,
    monitor_quit,
    monitor_screendump,
    open_monitor,
    qemu_sb16_silent_args,
    qemu_vga,
    remove_if_exists,
    run_cmd,
    send_monitor_command,
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
BOOT = WORKDIR / "sammax_setmuse_boot.bin"
KERNEL = WORKDIR / "sammax_setmuse_kernel.bin"
SHELL = WORKDIR / "shell.com"
AUTOEXEC = WORKDIR / "autoexec_setmuse.bat"
IMG = WORKDIR / "sammax_cd_setmuse.img"
MONITOR = Path(unique_monitor_socket("sammax-cd-setmuse"))
SCREENSHOT = BUILDDIR / "sammax_cd_setmuse_screen.ppm"
TEXTMEM = BUILDDIR / "sammax_cd_setmuse_b800.bin"
TIMEOUT = int(os.environ.get("SAMMAX_CD_SETMUSE_TIMEOUT", "35"))


def build_artifacts():
    prepare_cd_image(WORKDIR)
    AUTOEXEC.write_bytes(b"D:\r\nCD \\SAMNMAX\r\nSETMUSE\r\nEXIT\r\n")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", str(SHELL)])
    run_cmd(["python3", "scripts/mkimage.py", str(BOOT), str(KERNEL), str(IMG), str(SHELL), str(AUTOEXEC)])


def run_qemu():
    remove_if_exists(str(MONITOR))
    remove_if_exists(str(SCREENSHOT))
    remove_if_exists(str(TEXTMEM))
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
    ready = False
    try:
        sock = open_monitor(str(MONITOR), timeout=10)
        ready = wait_for_output(stdout_chunks, "DOS/4GW Protected Mode Run-time", timeout=TIMEOUT, stop_markers=("EXC ", "INT 21h AH="))
        if ready:
            time.sleep(8)
            send_monitor_key(sock, "ret", delay=2)
        monitor_screendump(sock, str(SCREENSHOT), delay=1)
        send_monitor_command(sock, f"pmemsave 0xb8000 4000 {TEXTMEM}", delay=1)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), ready


def text_screen():
    return read_text_screen(TEXTMEM).rstrip()


def main():
    build_artifacts()
    output, ready = run_qemu()
    if os.environ.get("SAMMAX_CD_SETMUSE_DUMP_SERIAL"):
        print("\n--- Sam & Max SETMUSE serial output ---")
        print(output)
        print("--- end ---")
    ok = check_markers(
        output,
        required=("DOS/4GW Protected Mode Run-time",),
        forbidden=("EXC ", "INT 21h AH=", "Bad command", "No such file", "Not enough memory"),
        output_label="Sam & Max SETMUSE serial output",
    )
    screen = text_screen()
    for marker in ("Sound Blaster 16", "Sound Blaster Pro", "General MIDI", "Roland"):
        if marker not in screen:
            print(f"  FAIL: missing SETMUSE card '{marker}'")
            ok = False
        else:
            print(f"  PASS: found SETMUSE card '{marker}'")
    if not ready:
        print("  FAIL: timed out waiting for SETMUSE startup")
        ok = False
    if not ok:
        print("\n--- Sam & Max SETMUSE text screen ---")
        print(screen)
        print("--- end ---")
        print("\n--- Sam & Max SETMUSE serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nSam & Max SETMUSE card-list smoke passed.")


if __name__ == "__main__":
    main()
