#!/usr/bin/env python3
import argparse
import os
import shutil
import struct
import subprocess
import sys
import threading
import time

from testlib import open_monitor, qemu_binary, qemu_vga, send_monitor_key, send_monitor_text, stop_qemu, wait_for_output


MONITOR = os.path.join("build", "run_stunt_island.sock")
DEFAULT_IMAGE = "build/stunt_hd.img"
CURRENT_IMAGE = "build/run_stunt_island_current.img"
CURRENT_KERNEL = "build/run_stunt_island_kernel.bin"


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


def current_kernel_enabled(value):
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
    parser.add_argument(
        "--no-current-kernel",
        action="store_true",
        default=not current_kernel_enabled(os.environ.get("LAINDOS_STUNT_CURRENT_KERNEL", "1")),
        help="boot the image as-is instead of patching in a kernel built from current source",
    )
    return parser.parse_args()


def send_command(sock, command):
    send_monitor_text(sock, command, delay=0.03)
    send_monitor_key(sock, "ret", delay=0.15)


def run_checked(command):
    subprocess.run(command, check=True)


def raw_83(name):
    parts = name.upper().split(".", 1)
    base = parts[0].encode("ascii")[:8].ljust(8)
    ext = (parts[1].encode("ascii") if len(parts) > 1 else b"")[:3].ljust(3)
    return base + ext


def replace_root_file(image_path, root_name, host_path):
    with open(image_path, "rb") as f:
        image = bytearray(f.read())
    with open(host_path, "rb") as f:
        data = f.read()

    bps = struct.unpack_from("<H", image, 11)[0]
    spc = image[13]
    reserved = struct.unpack_from("<H", image, 14)[0]
    fats = image[16]
    root_entries = struct.unpack_from("<H", image, 17)[0]
    fat_secs = struct.unpack_from("<H", image, 22)[0]
    if image[0x36:0x3E] != b"FAT16   ":
        raise RuntimeError("current-kernel patching only supports FAT16 Stunt images")
    root_secs = (root_entries * 32 + bps - 1) // bps
    fat_start = reserved * bps
    root_start = (reserved + fats * fat_secs) * bps
    data_start = (reserved + fats * fat_secs + root_secs) * bps
    cluster_bytes = bps * spc
    target = raw_83(root_name)

    for off in range(root_start, root_start + root_entries * 32, 32):
        entry = image[off:off + 32]
        if entry[0] == 0:
            break
        if entry[0] == 0xE5 or entry[11] == 0x0F:
            continue
        if entry[0:11] != target:
            continue
        first = struct.unpack_from("<H", entry, 26)[0]
        size = struct.unpack_from("<I", entry, 28)[0]
        capacity = max(cluster_bytes, ((size + cluster_bytes - 1) // cluster_bytes) * cluster_bytes)
        if len(data) > capacity:
            raise RuntimeError(f"replacement too large for {root_name}: {len(data)} > {capacity}")
        cluster = first
        written = 0
        while written < capacity:
            data_off = data_start + (cluster - 2) * cluster_bytes
            chunk = data[written:written + cluster_bytes]
            image[data_off:data_off + cluster_bytes] = chunk.ljust(cluster_bytes, b"\0")
            written += cluster_bytes
            fat_off = fat_start + cluster * 2
            cluster = struct.unpack_from("<H", image, fat_off)[0]
            if cluster >= 0xFFF8:
                break
        struct.pack_into("<I", image, off + 28, len(data))
        with open(image_path, "wb") as f:
            f.write(image)
        return
    raise RuntimeError(f"root file not found: {root_name}")


def prepare_current_image(base_image):
    run_checked(["nasm", "-DBOOT_FILE=\"SHELL   COM\"", "-f", "bin", "src/kernel.asm", "-o", CURRENT_KERNEL])
    shutil.copyfile(base_image, CURRENT_IMAGE)
    replace_root_file(CURRENT_IMAGE, "KERNEL.SYS", CURRENT_KERNEL)
    return os.path.abspath(CURRENT_IMAGE)


def main():
    # mise runs tasks with stdout/stderr on non-blocking pipes; Python's
    # buffered writes then die with BlockingIOError once the pipe fills
    for stream in (sys.stdout, sys.stderr):
        try:
            os.set_blocking(stream.fileno(), True)
        except (OSError, ValueError):
            pass
    args = parse_args()
    image = os.path.abspath(args.image)
    if not os.path.isfile(image):
        print(f"Missing Stunt Island image: {image}", file=sys.stderr)
        print("Set LAINDOS_STUNT_IMAGE or build one with scripts/build_stunt_hd.py first.", file=sys.stderr)
        return 1

    os.makedirs("build", exist_ok=True)
    if not args.no_current_kernel:
        image = prepare_current_image(image)
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
    if not args.no_current_kernel:
        print(f"Patched current source kernel into disposable image {CURRENT_IMAGE}.")
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
