#!/usr/bin/env python3
import os
import shutil
import sys
import tempfile
import time
import zipfile
from pathlib import Path
from testlib import (
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
MONITOR = Path(tempfile.gettempdir()) / "laindos-sammax-cd-setmuse.sock"
SCREENSHOT = BUILDDIR / "sammax_cd_setmuse_screen.ppm"
TEXTMEM = BUILDDIR / "sammax_cd_setmuse_b800.bin"
TIMEOUT = int(os.environ.get("SAMMAX_CD_SETMUSE_TIMEOUT", "35"))


def extract_member(archive, name, output):
    info = archive.getinfo(name)
    if output.exists() and output.stat().st_size == info.file_size:
        return
    with archive.open(info) as src, open(output, "wb") as dst:
        shutil.copyfileobj(src, dst)


def prepare_cd_image():
    if not os.path.exists(ARCHIVE):
        print(f"Missing {ARCHIVE}", file=sys.stderr)
        sys.exit(1)
    WORKDIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ARCHIVE) as archive:
        extract_member(archive, "BG GOLD 3.cue", CUE)
        extract_member(archive, "BG GOLD 3.bin", BIN)
    run_cmd(["python3", "scripts/extract_mode1_2352.py", str(CUE), str(ISO)])


def build_artifacts():
    prepare_cd_image()
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
        "-vnc", "127.0.0.1:58",
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
    if not TEXTMEM.exists():
        return ""
    data = TEXTMEM.read_bytes()
    lines = []
    for row in range(25):
        chars = []
        for col in range(80):
            ch = data[(row * 80 + col) * 2]
            chars.append(chr(ch) if 32 <= ch < 127 else " ")
        lines.append("".join(chars).rstrip())
    return "\n".join(lines).rstrip()


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
