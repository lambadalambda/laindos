#!/usr/bin/env python3
"""Install the Normality demo from the Sam & Max CD and launch it.

Drives the Gremlin "Install and Setup" program end to end through the
CDReader menu: language dialog, welcome screen, installation choice,
directory prompt, the shelled-out copy phase, and the exit confirmation.
Afterwards it escapes back to the DOS prompt, runs C:\\NORMINC\\NORMINC.BAT,
and checks that NORM.EXE takes over the framebuffer.
"""
import os
import re
import sys
import time
import shutil
import zipfile
import tempfile
from pathlib import Path

from testlib import (
    collect_output, framebuffer_active, qemu_binary, qemu_vga,
    qemu_sb16_adlib_silent_args, start_qemu, stop_qemu, open_monitor,
    send_monitor_command, monitor_quit, monitor_screendump, run_cmd,
    wait_for_output, remove_if_exists,
)

ARCHIVE = "vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip"
BUILDDIR = Path(os.environ.get("LAINDOS_TEST_BUILD_DIR", "build"))
WORKDIR = BUILDDIR / "sammax_cd"
CUE = WORKDIR / "BG GOLD 3.cue"
BIN = WORKDIR / "BG GOLD 3.bin"
ISO = WORKDIR / "BG_GOLD_3_data.iso"
BOOT = WORKDIR / "normality_install_boot.bin"
KERNEL = WORKDIR / "normality_install_kernel.bin"
SHELL = WORKDIR / "shell.com"
AUTOEXEC = WORKDIR / "autoexec_normality_install.bat"
IMG = WORKDIR / "normality_install.img"
SERIAL = WORKDIR / "normality_install_serial.txt"
MONITOR = Path(tempfile.gettempdir()) / "laindos-normality-install.sock"
TEXTMEM = BUILDDIR / "normality_install_b800.bin"
SCREENSHOT = BUILDDIR / "normality_install_screen.ppm"
TRACE_DOS = os.environ.get("NORMALITY_INSTALL_TRACE_DOS", "60000")
ICOUNT = os.environ.get("SAMMAX_CD_PROBE_ICOUNT", "shift=6")
TIMEOUT = int(os.environ.get("NORMALITY_INSTALL_TIMEOUT", "1500"))
PROMPT_RE = re.compile(r"[A-Z]:\\[^|]*>")


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
    AUTOEXEC.write_bytes(b"D:\r\nINSTALL\r\n")
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", str(BOOT)])
    kernel_cmd = ["nasm", '-DBOOT_FILE="SHELL   COM"', "-f", "bin", "src/kernel.asm", "-o", str(KERNEL)]
    if TRACE_DOS:
        kernel_cmd.insert(1, f"-DTRACE_DOS={TRACE_DOS}")
    run_cmd(kernel_cmd)
    run_cmd(["nasm", "-f", "bin", "programs/shell.asm", "-o", str(SHELL)])
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd160m",
        str(BOOT), str(KERNEL), str(IMG), str(SHELL), str(AUTOEXEC),
    ])


def text_screen(sock, path):
    if os.path.exists(path):
        os.unlink(path)
    send_monitor_command(sock, f"pmemsave 0xb8000 4000 {path}", delay=0.3)
    if not os.path.exists(path):
        return ""
    data = Path(path).read_bytes()
    lines = []
    for row in range(25):
        chars = []
        for col in range(80):
            ch = data[(row * 80 + col) * 2]
            chars.append(chr(ch) if 32 <= ch < 127 else " ")
        lines.append("".join(chars).rstrip())
    return "\n".join(lines)


def screen_has_highlighted_normality(sock, path):
    send_monitor_command(sock, f"pmemsave 0xb8000 4000 {path}", delay=0.3)
    if not os.path.exists(path):
        return False
    data = Path(path).read_bytes()
    for row in range(25):
        text = "".join(
            chr(data[(row * 80 + col) * 2]) if 32 <= data[(row * 80 + col) * 2] < 127 else " "
            for col in range(80))
        attrs = {data[(row * 80 + col) * 2 + 1] for col in range(80)}
        if "NORMALITY" in text.upper() and 0x17 in attrs:
            return True
    return False


def output_text(chunks):
    return b"".join(chunks).decode("latin-1", errors="replace")


def status_line(screen):
    return screen.split("\n")[24] if screen.count("\n") >= 24 else ""


def type_line(sock, text):
    keymap = {" ": "spc", "\\": "backslash", ":": "shift-semicolon", ".": "dot"}
    for ch in text:
        send_monitor_command(sock, f"sendkey {keymap.get(ch, ch)}")
        time.sleep(0.15)
    send_monitor_command(sock, "sendkey ret")
    time.sleep(0.8)


def main():
    build_artifacts()
    remove_if_exists(str(MONITOR))
    for stale in (TEXTMEM, SCREENSHOT):
        if stale.exists():
            stale.unlink()
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
        "-vnc", "127.0.0.1:62",
        *qemu_sb16_adlib_silent_args(),
    ])
    proc, stdout_chunks, stderr_chunks, threads = start_qemu(cmd)
    sock = None
    failed = False
    try:
        sock = open_monitor(str(MONITOR), timeout=10)
        if not wait_for_output(stdout_chunks, "LainDOS Shell", timeout=15,
                               stop_markers=("EXC ", "INT 21h AH=", "Runtime error 200")):
            print("FAIL: shell did not boot")
            sys.exit(1)
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            screen = text_screen(sock, str(TEXTMEM))
            if "CDReader" in screen and "BESTSELLER GAMES GOLD 3" in screen:
                break
            time.sleep(0.5)
        else:
            print("FAIL: CDReader menu did not appear")
            sys.exit(1)
        found = False
        for _ in range(12):
            if screen_has_highlighted_normality(sock, str(TEXTMEM)):
                found = True
                break
            send_monitor_command(sock, "sendkey down")
            time.sleep(0.5)
        if not found:
            print("FAIL: NORMALITY entry not found in CDReader menu")
            sys.exit(1)
        print("NORMALITY highlighted, launching installer")
        send_monitor_command(sock, "sendkey ret")
        time.sleep(3.0)

        launched = False
        install_done = False
        esc_count = 0
        last_change = time.monotonic()
        last_screen = ""
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline:
            screen = text_screen(sock, str(TEXTMEM))
            if screen != last_screen:
                last_screen = screen
                last_change = time.monotonic()
            up = screen.upper()
            st = status_line(screen).upper()
            key = None
            if "EXIT INSTALL AND SETUP" in up:
                install_done = True
                print("state: exit confirm -> Yes")
                send_monitor_command(sock, "sendkey up")
                time.sleep(0.7)
                key = "ret"
            elif "READ ABOUT ANY LATEST CHANGES" in st:
                install_done = True
                print("state: post-install menu -> Exit")
                send_monitor_command(sock, "sendkey down")
                time.sleep(0.7)
                send_monitor_command(sock, "sendkey down")
                time.sleep(0.7)
                key = "ret"
            elif "SELECT ENGLISH LANGUAGE" in st:
                print("state: language dialog")
                key = "ret"
            elif "PRESS A KEY OR CLICK MOUSE" in st:
                print("state: continue dialog")
                key = "ret"
            elif "INSTALL THE NORMAL INSTALLATION" in st:
                print("state: installation choice")
                key = "ret"
            elif "TYPE IN THE NAME OF THE DIRECTORY" in st:
                print("state: directory prompt")
                key = "ret"
            elif "WEITER MIT TASTE" in up:
                print("state: launch instructions")
                key = "ret"
            elif install_done and PROMPT_RE.search(screen):
                print("state: DOS prompt, launching demo")
                type_line(sock, "c:")
                type_line(sock, "cd \\norminc")
                type_line(sock, "norminc")
                launched = True
                break
            elif install_done and "BESTSELLER" in up and "PROGRAMM W" in up:
                if esc_count >= 5:
                    print("FAIL: CDReader did not exit after 5 ESC presses")
                    print(screen)
                    sys.exit(1)
                esc_count += 1
                print("state: CDReader menu -> ESC")
                send_monitor_command(sock, "sendkey esc")
                time.sleep(5.0)
                last_change = time.monotonic()
                continue
            if key:
                send_monitor_command(sock, f"sendkey {key}")
                time.sleep(2.5)
                last_change = time.monotonic()
                continue
            if time.monotonic() - last_change > 180:
                print("FAIL: install flow stalled; last screen:")
                print(last_screen)
                sys.exit(1)
            time.sleep(2.0)
        if not launched:
            print("FAIL: never reached a DOS prompt to launch the demo; last screen:")
            print(last_screen)
            sys.exit(1)

        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if "EXEC norm.EXE" in output_text(stdout_chunks):
                print("  PASS: NORM.EXE launched")
                break
            time.sleep(1.0)
        else:
            print("FAIL: NORM.EXE was not executed")
            failed = True
        time.sleep(45)
        monitor_screendump(sock, str(SCREENSHOT))
        failed = not framebuffer_active(str(SCREENSHOT), "Normality framebuffer") or failed
        serial = output_text(stdout_chunks)
        for bad in ("EXC ", "INT 21h AH=", "Runtime error 200",
                    "Missing argument", "Wildcard not supported"):
            if bad in serial:
                print(f"FAIL: serial contains '{bad}'")
                failed = True
        if failed:
            sys.exit(1)
        print("\nNormality install test passed: demo installed from CD and started.")
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


if __name__ == "__main__":
    main()
