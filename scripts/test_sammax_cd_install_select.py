#!/usr/bin/env python3
import os
import sys
import time
import shutil
import zipfile
import tempfile
from pathlib import Path

from testlib import (
    collect_output, qemu_binary, qemu_vga, qemu_sb16_adlib_silent_args,
    start_qemu, stop_qemu, open_monitor, send_monitor_command,
    monitor_quit, run_cmd, wait_for_output, remove_if_exists,
)

ARCHIVE = "vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip"
BUILDDIR = Path(os.environ.get("LAINDOS_TEST_BUILD_DIR", "build"))
WORKDIR = BUILDDIR / "sammax_cd"
CUE = WORKDIR / "BG GOLD 3.cue"
BIN = WORKDIR / "BG GOLD 3.bin"
ISO = WORKDIR / "BG_GOLD_3_data.iso"
BOOT = WORKDIR / "install_select_probe_boot.bin"
KERNEL = WORKDIR / "install_select_probe_kernel.bin"
SHELL = WORKDIR / "shell.com"
AUTOEXEC = WORKDIR / "autoexec_install_select_probe.bat"
IMG = WORKDIR / "sammax_cd_install_select_probe.img"
SERIAL = WORKDIR / "install_select_probe_serial.txt"
MONITOR = Path(tempfile.gettempdir()) / "laindos-sammax-cd-install-select-probe.sock"
TEXTMEM = BUILDDIR / "sammax_cd_install_select_probe_b800.bin"
BDA_DUMP = BUILDDIR / "sammax_cd_install_select_probe_bda.bin"
TRACE_DOS = os.environ.get("SAMMAX_CD_INSTALL_TRACE_DOS", "12000")
ICOUNT = os.environ.get("SAMMAX_CD_PROBE_ICOUNT", "shift=6")
TIMEOUT = int(os.environ.get("SAMMAX_CD_PROBE_TIMEOUT", "30"))


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


def text_screen_with_attrs(sock, path):
    send_monitor_command(sock, f"pmemsave 0xb8000 4000 {path}", delay=0.3)
    if not os.path.exists(path):
        return ""
    data = Path(path).read_bytes()
    lines = []
    for row in range(25):
        chars = []
        for col in range(80):
            ch = data[(row * 80 + col) * 2]
            at = data[(row * 80 + col) * 2 + 1]
            chars.append(chr(ch) if 32 <= ch < 127 else " ")
        attr_runs = []
        prev_at = None
        run_start = 0
        for col in range(80):
            at = data[(row * 80 + col) * 2 + 1]
            if at != prev_at:
                if prev_at is not None:
                    attr_runs.append((run_start, col, prev_at))
                prev_at = at
                run_start = col
        if prev_at is not None:
            attr_runs.append((run_start, 80, prev_at))
        runs = " ".join(f"[{s}-{e}:0x{a:02x}]" for s, e, a in attr_runs)
        lines.append(f"R{row:02d} {runs} |{''.join(chars).rstrip()}|")
    return "\n".join(lines)


def bda_keyboard_buffer(sock, path):
    send_monitor_command(sock, f"pmemsave 0x400 0x100 {path}", delay=0.3)
    if not os.path.exists(path):
        return None
    data = Path(path).read_bytes()
    if len(data) < 0x1E:
        return None
    head = int.from_bytes(data[0x1A:0x1C], "little")
    tail = int.from_bytes(data[0x1C:0x1E], "little")
    return head, tail


def highlight_row_from_screen(screen):
    for line in screen.split("\n"):
        if "0x17" in line and "SAM" in line.upper():
            return "SAM & MAX"
        if "0x17" in line and "REBEL" in line.upper():
            return "Demo: Rebel Assault"
        if "0x17" in line and "DIG" in line.upper():
            return "Demo: The Dig"
        if "0x17" in line and "FANTASY" in line.upper():
            return "Demo: Fantasy General"
    return None


def output_text(chunks):
    return b"".join(chunks).decode("latin-1", errors="replace")


def wait_for_upper_output(chunks, marker, timeout):
    deadline = time.monotonic() + timeout
    marker = marker.upper()
    while time.monotonic() < deadline:
        output = output_text(chunks).upper()
        if marker in output:
            return True
        if any(m in output for m in ("EXC ", "INT 21H AH=", "RUNTIME ERROR 200", "BAD COMMAND OR FILE NAME")):
            return False
        time.sleep(0.05)
    return False


def main():
    build_artifacts()
    remove_if_exists(str(MONITOR))
    if TEXTMEM.exists():
        TEXTMEM.unlink()
    if BDA_DUMP.exists():
        BDA_DUMP.unlink()
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
        "-vnc", "127.0.0.1:61",
        *qemu_sb16_adlib_silent_args(),
    ])
    proc, stdout_chunks, stderr_chunks, threads = start_qemu(cmd)
    sock = None
    bda_path = str(BDA_DUMP)
    try:
        sock = open_monitor(str(MONITOR), timeout=10)
        if not wait_for_output(stdout_chunks, "LainDOS Shell", timeout=15,
                               stop_markers=("EXC ", "INT 21h AH=", "Runtime error 200")):
            print("FAIL: shell did not boot")
            sys.exit(1)
        deadline = time.monotonic() + TIMEOUT
        menu_screen = ""
        while time.monotonic() < deadline:
            menu_screen = text_screen_with_attrs(sock, str(TEXTMEM))
            if "CDReader" in menu_screen and "BESTSELLER GAMES GOLD 3" in menu_screen:
                break
            if any(m.encode() in b"".join(stdout_chunks) for m in ("EXC ", "INT 21h AH=", "Runtime error 200")):
                break
            time.sleep(0.5)
        else:
            print("FAIL: INSTALL menu did not appear")
            sys.exit(1)
        before_highlight = highlight_row_from_screen(menu_screen)
        print(f"Initial highlight row: {before_highlight}")
        send_monitor_command(sock, "sendkey down")
        time.sleep(0.5)
        menu_screen = text_screen_with_attrs(sock, str(TEXTMEM))
        after_down_highlight = highlight_row_from_screen(menu_screen)
        print(f"After Down: highlight row: {after_down_highlight}")
        bda = bda_keyboard_buffer(sock, bda_path)
        print(f"BDA after Down: {bda}")
        send_monitor_command(sock, "sendkey down")
        time.sleep(0.5)
        menu_screen = text_screen_with_attrs(sock, str(TEXTMEM))
        after_second_down_highlight = highlight_row_from_screen(menu_screen)
        print(f"After second Down: highlight row: {after_second_down_highlight}")
        bda = bda_keyboard_buffer(sock, bda_path)
        print(f"BDA after second Down: {bda}")
        send_monitor_command(sock, "sendkey ret")
        time.sleep(1.5)
        menu_screen = text_screen_with_attrs(sock, str(TEXTMEM))
        after_enter_highlight = highlight_row_from_screen(menu_screen)
        print(f"After Enter: highlight row: {after_enter_highlight}")
        bda = bda_keyboard_buffer(sock, bda_path)
        print(f"BDA after Enter: {bda}")
        ok = True
        if before_highlight != "SAM & MAX":
            print("FAIL: initial highlight is not on SAM & MAX")
            ok = False
        if after_down_highlight != "Demo: Rebel Assault":
            print("FAIL: first Down did not move to Rebel Assault")
            ok = False
        if after_second_down_highlight != "Demo: The Dig":
            print("FAIL: second Down did not move to The Dig")
            ok = False
        if not wait_for_upper_output(stdout_chunks, "OPEN START.BAT", timeout=20):
            print("FAIL: installer selection did not launch START.BAT")
            ok = False
        serial = output_text(stdout_chunks)
        for bad in ("EXC ", "INT 21h AH=", "Runtime error 200"):
            if bad in serial:
                print(f"FAIL: serial contains '{bad}' after sendkey interactions")
                ok = False
        if not ok:
            sys.exit(1)
        print("\nINSTALL selection probe passed: The Dig menu entry launches START.BAT.")
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
        if os.path.exists(bda_path):
            os.unlink(bda_path)


if __name__ == "__main__":
    main()
