#!/usr/bin/env python3
import os
import shlex
import shutil
import struct

from fatlib import FatImage, entry_cluster, entry_size, find_entry
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
    qemu_binary,
    qemu_sb16_adlib_silent_args,
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
BOOT = WORKDIR / "sammax_setmuse_save_boot.bin"
KERNEL = WORKDIR / "sammax_setmuse_save_kernel.bin"
SHELL = WORKDIR / "shell.com"
AUTOEXEC = WORKDIR / "autoexec_setmuse_save.bat"
IMG = WORKDIR / "sammax_cd_setmuse_save.img"
MONITOR = Path(unique_monitor_socket("sammax-cd-setmuse-save"))
SCREENSHOT = BUILDDIR / "sammax_cd_setmuse_save_screen.ppm"
TEXTMEM = BUILDDIR / "sammax_cd_setmuse_save_b800.bin"
TIMEOUT = int(os.environ.get("SAMMAX_CD_SETMUSE_SAVE_TIMEOUT", "55"))
KEYS = os.environ.get(
    "SAMMAX_CD_SETMUSE_SAVE_KEYS",
    "ret up up up up up up ret down ret ret down down down down down down ret j",
).split()


def build_artifacts():
    prepare_cd_image(WORKDIR)
    AUTOEXEC.write_bytes(b"D:\r\nCD \\SAMNMAX\r\nSETMUSE\r\nEXIT\r\n")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    kernel_cmd = ["nasm", '-DBOOT_FILE="SHELL   COM"']
    kernel_cmd.extend(shlex.split(os.environ.get("SAMMAX_CD_SETMUSE_KERNEL_DEFINES", "")))
    kernel_cmd.extend(["-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
    run_cmd(kernel_cmd)
    run_cmd(["python3", "scripts/build_shell_com.py", str(SHELL)])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd160m", str(BOOT), str(KERNEL), str(IMG), str(SHELL), str(AUTOEXEC),
    ])


def run_qemu():
    remove_if_exists(str(MONITOR))
    remove_if_exists(str(SCREENSHOT))
    remove_if_exists(str(TEXTMEM))
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={IMG},format=raw,if=ide,index=0,media=disk",
        "-drive", f"file={ISO},format=raw,if=ide,index=1,media=cdrom,readonly=on",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-vnc", unique_vnc_arg(),
        *qemu_sb16_adlib_silent_args(),
    ])
    sock = None
    ready = False
    halted = False
    try:
        sock = open_monitor(str(MONITOR), timeout=10)
        ready = wait_for_output(stdout_chunks, "DOS/4GW Protected Mode Run-time", timeout=TIMEOUT, stop_markers=("EXC ", "Assertion failed", "INT 21h AH="))
        if ready:
            time.sleep(8)
            for key in KEYS:
                send_monitor_key(sock, key, delay=1.5)
            halted = wait_for_output(stdout_chunks, "HALT", timeout=TIMEOUT, stop_markers=("EXC ", "Assertion failed", "INT 21h AH="))
        monitor_screendump(sock, str(SCREENSHOT), delay=1)
        send_monitor_command(sock, f"pmemsave 0xb8000 4000 {TEXTMEM}", delay=1)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), ready, halted


def saved_ini_size():
    img = FatImage.from_file(str(IMG))
    samnmax_dir = find_entry(img.root_dir(), "SAMNMAX.CD")
    if samnmax_dir is None:
        return None
    dir_data = img.read_chain(entry_cluster(samnmax_dir))
    ini = find_entry(dir_data, "SETMUSE.INI")
    if ini is None:
        return None
    return entry_size(ini)


def text_screen():
    return read_text_screen(TEXTMEM).rstrip()


def main():
    build_artifacts()
    output, ready, halted = run_qemu()
    if os.environ.get("SAMMAX_CD_SETMUSE_SAVE_DUMP_SERIAL"):
        print("\n--- Sam & Max SETMUSE save serial output ---")
        print(output)
        print("--- end ---")
    ok = check_markers(
        output,
        required=("DOS/4GW Protected Mode Run-time",),
        forbidden=("EXC ", "Assertion failed", "INT 21h AH=", "Bad command", "No such file", "Not enough memory"),
        output_label="Sam & Max SETMUSE save serial output",
    )
    if not ready:
        print("  FAIL: timed out waiting for SETMUSE startup")
        ok = False
    if not halted:
        print("  FAIL: SETMUSE save flow did not return to shell")
        ok = False
    ini_size = saved_ini_size()
    if ini_size is None:
        print("  FAIL: missing C:\\SAMNMAX.CD\\SETMUSE.INI")
        ok = False
    elif ini_size == 0:
        print("  FAIL: C:\\SAMNMAX.CD\\SETMUSE.INI is empty")
        ok = False
    else:
        print(f"  PASS: C:\\SAMNMAX.CD\\SETMUSE.INI size {ini_size} bytes")
    if not ok:
        print("\n--- Sam & Max SETMUSE save text screen ---")
        print(text_screen())
        print("--- end ---")
        print("\n--- Sam & Max SETMUSE save serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nSam & Max SETMUSE save smoke passed.")


if __name__ == "__main__":
    main()
