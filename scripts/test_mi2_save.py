#!/usr/bin/env python3
import hashlib
import os
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
from testlib import qemu_binary

IMG = os.environ.get("LAINDOS_MI2_SAVE_IMG", "build/games_hd_all.img")
MONITOR = os.path.join(tempfile.gettempdir(), "laindos-mi2-save.sock")
SCREEN_DIALOG = "build/mi2_save_dialog.ppm"
SCREEN_AFTER_OK = "build/mi2_save_after_ok.ppm"
MIN_SAVE_SIZE = 1024


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        sys.exit(result.returncode)


def fat12_get(fat, cluster):
    off = cluster + (cluster >> 1)
    if cluster & 1:
        return ((fat[off] >> 4) | (fat[off + 1] << 4)) & 0xFFF
    return (fat[off] | ((fat[off + 1] & 0x0F) << 8)) & 0xFFF


def fat16_get(fat, cluster):
    return struct.unpack_from("<H", fat, cluster * 2)[0]


def read_cluster_chain(image, fat, fat_bits, data_start, bps, spc, cluster):
    data = bytearray()
    seen = set()
    eoc = 0xFFF0 if fat_bits == 16 else 0xFF0
    while 2 <= cluster < eoc and cluster not in seen:
        seen.add(cluster)
        off = (data_start + (cluster - 2) * spc) * bps
        data.extend(image[off:off + spc * bps])
        cluster = fat16_get(fat, cluster) if fat_bits == 16 else fat12_get(fat, cluster)
    return bytes(data)


def find_entry(directory, name):
    for off in range(0, len(directory), 32):
        first = directory[off]
        if first == 0:
            break
        if first != 0xE5 and directory[off:off + 11] == name:
            return directory[off:off + 32]
    return None


def read_file_from_image(path_parts):
    with open(IMG, "rb") as f:
        image = f.read()
    bps = struct.unpack_from("<H", image, 0x0B)[0]
    spc = image[0x0D]
    reserved = struct.unpack_from("<H", image, 0x0E)[0]
    fats = image[0x10]
    root_entries = struct.unpack_from("<H", image, 0x11)[0]
    fat_secs = struct.unpack_from("<H", image, 0x16)[0]
    root_start = reserved + fats * fat_secs
    root_secs = (root_entries * 32 + bps - 1) // bps
    data_start = root_start + root_secs
    fat = image[reserved * bps:(reserved + fat_secs) * bps]
    fat_bits = 16 if image[0x36:0x3E] == b"FAT16   " else 12
    directory = image[root_start * bps:(root_start + root_secs) * bps]
    entry = None
    for index, name in enumerate(path_parts):
        entry = find_entry(directory, name)
        if entry is None:
            return None, None
        cluster = struct.unpack_from("<H", entry, 26)[0]
        size = struct.unpack_from("<I", entry, 28)[0]
        data = read_cluster_chain(image, fat, fat_bits, data_start, bps, spc, cluster)
        if index == len(path_parts) - 1:
            return entry, data[:size]
        directory = data
    return entry, b""


def send_monitor(sock, command, delay=0.15):
    sock.sendall((command + "\n").encode("ascii"))
    time.sleep(delay)


def send_key(sock, key, delay=0.1):
    send_monitor(sock, f"sendkey {key}", delay)


def click(sock):
    send_monitor(sock, "mouse_button 1", 0.2)
    send_monitor(sock, "mouse_button 0", 0.5)


def move_relative(sock, dx, dy):
    while dx or dy:
        step_x = max(-100, min(100, dx))
        step_y = max(-100, min(100, dy))
        send_monitor(sock, f"mouse_move {step_x} {step_y}", 0.04)
        dx -= step_x
        dy -= step_y


def move_to(sock, x, y):
    move_relative(sock, -1000, -1000)
    move_relative(sock, x, y)
    time.sleep(0.2)


def wait_for(output_chunks, marker, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        output = b"".join(output_chunks).decode("utf-8", errors="replace")
        if marker in output:
            return True
        time.sleep(0.05)
    return False


def run_qemu_save_attempt():
    for path in [MONITOR, SCREEN_DIALOG, SCREEN_AFTER_OK]:
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
    proc = subprocess.Popen(
        [
            qemu_binary(),
            "-drive", f"file={IMG},format=raw",
            "-boot", "order=c",
            "-serial", "stdio",
            "-monitor", f"unix:{MONITOR},server,nowait",
            "-vnc", "127.0.0.1:50",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout = b""
    stderr = b""
    stdout_chunks = []
    stderr_chunks = []

    def reader(stream, chunks):
        while True:
            data = os.read(stream.fileno(), 4096)
            if not data:
                return
            chunks.append(data)

    for stream, chunks in [(proc.stdout, stdout_chunks), (proc.stderr, stderr_chunks)]:
        threading.Thread(target=reader, args=(stream, chunks), daemon=True).start()

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        if not wait_for(stdout_chunks, "C:\\>", 20):
            raise RuntimeError("shell prompt did not appear")
        deadline = time.time() + 8
        while True:
            try:
                sock.connect(MONITOR)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(0.05)
        sock.recv(4096)

        for key in ["c", "d", "spc", "m", "i", "2", "ret", "m", "o", "n", "k", "e", "y", "2", "ret"]:
            send_key(sock, key, 0.08)
        time.sleep(40)

        for key in ["1", "2", "3", "4", "ret"]:
            send_key(sock, key, 0.15)
        time.sleep(3)
        send_key(sock, "ret", 0.3)
        for key in ["1", "2", "3", "4", "ret"]:
            send_key(sock, key, 0.15)
        time.sleep(4)

        send_monitor(sock, "mouse_move -160 20", 0.2)
        click(sock)
        time.sleep(20)

        for _ in range(12):
            send_key(sock, "esc", 0.25)
        time.sleep(4)

        send_key(sock, "f5", 1)
        move_to(sock, 535, 166)
        click(sock)
        time.sleep(1)
        send_monitor(sock, f"screendump {SCREEN_DIALOG}", 1)

        move_to(sock, 75, 138)
        click(sock)
        for key in ["a", "u", "t", "o"]:
            send_key(sock, key, 0.2)

        move_to(sock, 530, 193)
        click(sock)
        time.sleep(1)
        click(sock)
        time.sleep(8)
        send_monitor(sock, f"screendump {SCREEN_AFTER_OK}", 1)
        send_monitor(sock, "quit", 0.2)
        try:
            stdout, stderr = proc.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            proc.send_signal(signal.SIGTERM)
            stdout, stderr = proc.communicate(timeout=5)
    finally:
        sock.close()
        if proc.poll() is None:
            proc.send_signal(signal.SIGTERM)
            try:
                stdout, stderr = proc.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                stdout, stderr = proc.communicate()
        try:
            os.unlink(MONITOR)
        except FileNotFoundError:
            pass

    output = (b"".join(stdout_chunks) + stdout).decode("utf-8", errors="replace")
    err = (b"".join(stderr_chunks) + stderr).decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def main():
    if not os.path.exists("vendor/Monkey_Island_2_-_LeChucks_Revenge_1991.zip"):
        print("Missing vendor/Monkey_Island_2_-_LeChucks_Revenge_1991.zip", file=sys.stderr)
        sys.exit(1)
    if not os.environ.get("LAINDOS_MI2_SAVE_SKIP_BUILD"):
        run(["python3", "scripts/build_games_hd_all.py"])
    before_entry, _ = read_file_from_image([b"MI2        ", b"SAVEGAME002"])
    if before_entry is not None:
        print("  FAIL: SAVEGAME.002 unexpectedly exists before save attempt")
        sys.exit(1)

    output = run_qemu_save_attempt()
    failed = False
    for marker in ["MiniDOS booted", "LainDOS Shell", "C:\\MI2>monkey2"]:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in ["FAIL:", "EXC ", "INT 21h AH="]:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True

    entry, data = read_file_from_image([b"MI2        ", b"SAVEGAME002"])
    if entry is None:
        print("  FAIL: MI2 did not create C:\\MI2\\SAVEGAME.002")
        failed = True
    elif not data.startswith(b"auto\x00"):
        digest = hashlib.sha256(data).hexdigest()
        print(f"  FAIL: SAVEGAME.002 does not start with auto name prefix, size={len(data)} sha256={digest}")
        failed = True
    elif len(data) < MIN_SAVE_SIZE:
        digest = hashlib.sha256(data).hexdigest()
        print(f"  FAIL: SAVEGAME.002 is unexpectedly small, size={len(data)} sha256={digest}")
        failed = True
    else:
        digest = hashlib.sha256(data).hexdigest()
        print(f"  PASS: SAVEGAME.002 created, size={len(data)} sha256={digest}")

    if failed:
        print("\n--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        print(f"Screenshots: {SCREEN_DIALOG}, {SCREEN_AFTER_OK}")
        sys.exit(1)
    print("\nMI2 save-game test passed.")


if __name__ == "__main__":
    main()
