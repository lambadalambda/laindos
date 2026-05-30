#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import threading
import time

from testlib import open_monitor, qemu_binary, qemu_vga, send_monitor_key, send_monitor_text, stop_qemu, wait_for_output


MONITOR = os.path.join("build", "run_stunt_island.sock")
DEFAULT_IMAGE = "build/stunt_xmsfix_hd.img"


def read_stream_live(stream, chunks, dst):
    try:
        while True:
            data = os.read(stream.fileno(), 4096)
            if not data:
                return
            chunks.append(data)
            dst.write(data)
            dst.flush()
    except OSError:
        return


def snapshot_enabled(value):
    return value.lower() not in ("0", "false", "no", "off")


def parse_args():
    parser = argparse.ArgumentParser(description="Boot the local Stunt Island image and launch STUNT.")
    parser.add_argument(
        "--image",
        default=os.environ.get("LAINDOS_STUNT_IMAGE", DEFAULT_IMAGE),
        help=f"hard-disk image to boot, default: {DEFAULT_IMAGE}",
    )
    parser.add_argument(
        "--vnc",
        default=os.environ.get("LAINDOS_STUNT_VNC"),
        help="optional QEMU VNC endpoint; by default QEMU opens a normal visible window",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=20,
        help="seconds to wait for shell prompts before launching STUNT",
    )
    parser.add_argument(
        "--no-snapshot",
        action="store_true",
        default=not snapshot_enabled(os.environ.get("LAINDOS_STUNT_SNAPSHOT", "1")),
        help="write changes back to the image instead of using QEMU -snapshot",
    )
    parser.add_argument(
        "--no-launch",
        action="store_true",
        help="boot to the C: shell prompt without typing CD STUNTISL/STUNT",
    )
    return parser.parse_args()


def send_command(sock, command):
    send_monitor_text(sock, command, delay=0.03)
    send_monitor_key(sock, "ret", delay=0.15)


def main():
    args = parse_args()
    image = os.path.abspath(args.image)
    if not os.path.isfile(image):
        print(f"Missing Stunt Island image: {image}", file=sys.stderr)
        print("Set LAINDOS_STUNT_IMAGE or rebuild the local generated Stunt image first.", file=sys.stderr)
        return 1

    os.makedirs("build", exist_ok=True)
    try:
        os.unlink(MONITOR)
    except FileNotFoundError:
        pass

    qemu_args = [
        qemu_binary(),
        "-drive", f"file={image},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c",
        "-serial", "stdio",
        "-monitor", f"unix:{MONITOR},server,nowait",
        "-vga", qemu_vga(),
        "-device", "sb16",
    ]
    if not args.no_snapshot:
        qemu_args.append("-snapshot")
    if args.vnc:
        qemu_args.extend(["-vnc", args.vnc])

    print("Starting QEMU with the normal visible display window.")
    if args.vnc:
        print(f"Also enabling QEMU VNC endpoint {args.vnc}.")
    if not args.no_snapshot:
        print("Running with QEMU -snapshot; disk writes will be discarded.")

    proc = subprocess.Popen(qemu_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout_chunks = []
    stderr_chunks = []
    stdout_thread = threading.Thread(target=read_stream_live, args=(proc.stdout, stdout_chunks, sys.stdout.buffer), daemon=True)
    stderr_thread = threading.Thread(target=read_stream_live, args=(proc.stderr, stderr_chunks, sys.stderr.buffer), daemon=True)
    stdout_thread.start()
    stderr_thread.start()

    sock = None
    try:
        if not wait_for_output(stdout_chunks, "C:\\>", timeout=args.timeout, stop_markers=()):
            raise TimeoutError("timed out waiting for C:\\>")
        sock = open_monitor(MONITOR)
        if not args.no_launch:
            send_command(sock, "cd stuntisl")
            if not wait_for_output(stdout_chunks, "C:\\STUNTISL>", timeout=args.timeout, stop_markers=()):
                raise TimeoutError("timed out waiting for C:\\STUNTISL>")
            send_command(sock, "stunt")
            print("\nSTUNT launched. Press Ctrl-C here to stop QEMU.")
        else:
            print("\nBooted to shell. Press Ctrl-C here to stop QEMU.")
        proc.wait()
    except KeyboardInterrupt:
        print("\nStopping QEMU...")
        stop_qemu(proc)
    except Exception as exc:
        print(f"\n{exc}", file=sys.stderr)
        stop_qemu(proc)
        return 1
    finally:
        if sock:
            sock.close()
        stdout_thread.join(timeout=1)
        stderr_thread.join(timeout=1)
    assert proc.returncode is not None
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
