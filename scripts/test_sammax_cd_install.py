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
    open_monitor,
    qemu_binary,
    qemu_sb16_adlib_silent_args,
    qemu_vga,
    remove_if_exists,
    run_cmd,
    send_monitor_command,
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
BOOT = WORKDIR / "sammax_install_boot.bin"
KERNEL = WORKDIR / "sammax_install_kernel.bin"
SHELL = WORKDIR / "shell.com"
AUTOEXEC = WORKDIR / "autoexec_install.bat"
IMG = WORKDIR / "sammax_cd_install.img"
MONITOR = Path(tempfile.gettempdir()) / "laindos-sammax-cd-install.sock"
TEXTMEM = BUILDDIR / "sammax_cd_install_b800.bin"
TIMEOUT = int(os.environ.get("SAMMAX_CD_INSTALL_TIMEOUT", "30"))
ICOUNT = os.environ.get("SAMMAX_CD_INSTALL_ICOUNT", "shift=6")


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
    AUTOEXEC.write_bytes(b"D:\r\nINSTALL\r\nEXIT\r\n")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    run_cmd(["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", str(KERNEL)])
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", str(SHELL)])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd160m", str(BOOT), str(KERNEL), str(IMG), str(SHELL), str(AUTOEXEC),
    ])


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


def capture_text(sock):
    send_monitor_command(sock, f"pmemsave 0xb8000 4000 {TEXTMEM}", delay=0.5)
    return text_screen()


def run_qemu():
    remove_if_exists(str(MONITOR))
    remove_if_exists(str(TEXTMEM))
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
        "-vnc", "127.0.0.1:57",
        *qemu_sb16_adlib_silent_args(),
    ])
    proc, stdout_chunks, stderr_chunks, threads = start_qemu(cmd)
    sock = None
    shell_seen = False
    screen = ""
    try:
        sock = open_monitor(str(MONITOR), timeout=10)
        shell_seen = wait_for_output(stdout_chunks, "LainDOS Shell", timeout=15, stop_markers=("EXC ", "INT 21h AH=", "Runtime error 200"))
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline:
            screen = capture_text(sock)
            if "CDReader" in screen and "BESTSELLER GAMES GOLD 3" in screen:
                break
            if any(marker.encode() in b"".join(stdout_chunks) for marker in ("EXC ", "INT 21h AH=", "Runtime error 200")):
                break
            time.sleep(1)
        monitor_quit(sock, proc)
    finally:
        if sock is not None:
            sock.close()
        stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), shell_seen, screen


def main():
    build_artifacts()
    output, shell_seen, screen = run_qemu()
    ok = check_markers(
        output,
        required=("LainDOS Shell",),
        forbidden=("EXC ", "INT 21h AH=", "Runtime error 200", "Bad command", "No such file", "Not enough memory"),
        output_label="Sam & Max INSTALL serial output",
    )
    if not shell_seen:
        print("  FAIL: timed out waiting for LainDOS shell")
        ok = False
    for marker in ("CDReader", "BESTSELLER GAMES GOLD 3"):
        if marker not in screen:
            print(f"  FAIL: missing INSTALL screen marker '{marker}'")
            ok = False
        else:
            print(f"  PASS: found INSTALL screen marker '{marker}'")
    if not ok:
        print("\n--- Sam & Max INSTALL text screen ---")
        print(screen)
        print("--- end ---")
        print("\n--- Sam & Max INSTALL serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    print("\nSam & Max INSTALL smoke passed.")


if __name__ == "__main__":
    main()
