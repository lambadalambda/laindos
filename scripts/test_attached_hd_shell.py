#!/usr/bin/env python3
import argparse
import os
import re
import sys
import time

from testlib import build_dir, check_markers, finish_qemu, open_monitor, qemu_binary, run_cmd, start_qemu, wait_for_output


BUILDDIR = build_dir()
FLOPPY_IMG = os.path.join("build", "shell_monkey.img")
MONITOR = os.path.join(BUILDDIR, "attached_hd_shell.sock")
PROMPT_RE = re.compile(rb"[AC]:\\[^>\r\n]*>")
KEYMAP = {
    " ": "spc",
    "\\": "backslash",
    "/": "slash",
    ".": "dot",
    ":": "shift-semicolon",
    "-": "minus",
}


def infer_format(path):
    ext = os.path.splitext(path)[1].lower()
    if ext in (".vhd", ".vpc"):
        return "vpc"
    return "raw"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Boot shell_monkey.img with a local external hard disk attached as C:."
    )
    parser.add_argument(
        "image",
        nargs="?",
        default=os.environ.get("LAINDOS_HD_IMAGE"),
        help="hard-disk image path, or LAINDOS_HD_IMAGE",
    )
    parser.add_argument(
        "--format",
        default=os.environ.get("LAINDOS_HD_FORMAT"),
        help="QEMU disk format, default: vpc for .vhd/.vpc, raw otherwise",
    )
    parser.add_argument(
        "--expect",
        action="append",
        default=[],
        help="extra serial-output marker that must appear; may be repeated",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=15,
        help="seconds to wait for each shell command prompt",
    )
    args = parser.parse_args()
    if not args.image:
        parser.error("provide an image path or set LAINDOS_HD_IMAGE")
    args.image = os.path.abspath(args.image)
    if not os.path.isfile(args.image):
        parser.error(f"image does not exist: {args.image}")
    if not args.format:
        args.format = infer_format(args.image)
    return args


def build_floppy():
    run_cmd(["python3", "scripts/build_shell_monkey.py"])


def send_key(sock, key):
    sock.sendall(f"sendkey {key} 10\n".encode())
    time.sleep(0.02)


def send_text(sock, text):
    for ch in text:
        if ch.isalnum():
            key = ch.lower()
        elif ch in KEYMAP:
            key = KEYMAP[ch]
        else:
            raise ValueError(f"unmapped key {ch!r}")
        send_key(sock, key)


def prompt_count(chunks):
    return len(PROMPT_RE.findall(b"".join(chunks)))


def wait_for_prompt_count(chunks, count, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        output = b"".join(chunks)
        if len(PROMPT_RE.findall(output)) >= count:
            return
        for marker in (b"FAIL:", b"EXC ", b"INT 21h AH=", b"HALT"):
            if marker in output:
                raise RuntimeError(f"saw {marker!r} while waiting for prompt")
        time.sleep(0.02)
    raise TimeoutError("timed out waiting for prompt")


def send_command(sock, chunks, command, timeout):
    target = prompt_count(chunks) + 1
    send_text(sock, command)
    send_key(sock, "ret")
    wait_for_prompt_count(chunks, target, timeout)


def drive_shell(sock, chunks, timeout):
    send_command(sock, chunks, "c:", timeout)
    send_command(sock, chunks, "dir", timeout)
    send_text(sock, "exit")
    send_key(sock, "ret")


def run_qemu(image, disk_format, timeout):
    os.makedirs(BUILDDIR, exist_ok=True)
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass
    proc, stdout_chunks, stderr_chunks, threads = start_qemu([
        qemu_binary(),
        "-drive", f"file={FLOPPY_IMG},format=raw,if=floppy",
        "-drive", f"file={image},format={disk_format},if=ide,index=0,media=disk",
        "-snapshot",
        "-boot", "order=a",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-nographic",
    ])
    sock = None
    try:
        if not wait_for_output(stdout_chunks, "A:\\>", timeout=timeout, stop_markers=()):
            raise TimeoutError("timed out waiting for A:\\>")
        sock = open_monitor(MONITOR)
        drive_shell(sock, stdout_chunks, timeout)
    except Exception:
        proc.kill()
        proc.wait()
        for thread in threads:
            thread.join(timeout=1)
        raise
    finally:
        if sock:
            sock.close()
    output, _ = finish_qemu(
        proc,
        stdout_chunks,
        stderr_chunks,
        threads,
        timeout=8,
        stop_markers=("HALT", "Program exited, code=00"),
    )
    return output


def main():
    args = parse_args()
    build_floppy()
    output = run_qemu(args.image, args.format, args.timeout)
    required = ["A:\\>", "C:\\>", "Program exited, code=00", *args.expect]
    forbidden = ["FAIL:", "EXC ", "INT 21h AH=", "Path not found", "Bad command or file name"]
    if not check_markers(output, required=required, forbidden=forbidden):
        sys.exit(1)
    print("\nAttached hard-disk shell smoke passed.")


if __name__ == "__main__":
    main()
