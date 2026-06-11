#!/usr/bin/env python3
"""Drive Monkey Island 2 through launch, copy protection, intro skip, and an
in-game save, then verify SAVEGAME.002 lands on the disk image.

The choreography is state-driven: each phase is detected from QEMU
screendumps (PPM via the monitor) instead of fixed sleeps, and dialog
buttons are located by their border rows instead of fixed coordinates --
the SCUMM dialog position depends on the scene, so blind clicks miss.
"""
import hashlib
import os
import signal
import socket
import subprocess
import sys
import threading
import time

from fatlib import FatImage, entry_cluster, entry_size, find_entry
from testlib import run_cmd, unique_monitor_socket, unique_vnc_arg, qemu_binary

IMG = os.environ.get("LAINDOS_MI2_SAVE_IMG", "build/games_hd_all.img")
MONITOR = unique_monitor_socket("mi2-save")
STATE_PPM = "build/mi2_save_state.ppm"
SCREEN_DIALOG = "build/mi2_save_dialog.ppm"
SCREEN_AFTER_OK = "build/mi2_save_after_ok.ppm"
MIN_SAVE_SIZE = 1024

PURPLE = bytes((0x80, 0x00, 0xB0))
CYAN = bytes((0x57, 0xFF, 0xFF))
PINK = bytes((0xDF, 0x50, 0xDF))
DARKRED = bytes((0xA8, 0x1F, 0x1F))
BUTTON_BORDER = bytes((0xA8, 0x00, 0xA8))


def read_file_from_image(path_parts):
    img = FatImage.from_file(IMG)
    directory = img.root_dir()
    entry = None
    for index, name in enumerate(path_parts):
        entry = find_entry(directory, name)
        if entry is None:
            return None, None
        if index == len(path_parts) - 1:
            return entry, img.read_chain(entry_cluster(entry), entry_size(entry))
        directory = img.read_chain(entry_cluster(entry))
    return entry, b""


def load_ppm(path):
    with open(path, "rb") as f:
        data = f.read()
    if not data.startswith(b"P6"):
        return None
    idx = data.index(b"255\n") + 4
    body = data[idx:]
    if len(body) < 640 * 400 * 3:
        return None
    return body


def color_fraction(body, color, step=997):
    hits = 0
    samples = 0
    for i in range(0, len(body) - 3, 3 * step):
        samples += 1
        if body[i:i + 3] == color:
            hits += 1
    return hits / samples if samples else 0.0


def pixel(body, x, y):
    offset = (y * 640 + x) * 3
    return body[offset:offset + 3]


def button_rows(body):
    """Rows of dialog button top-borders: ~100px magenta runs on the right
    that do not extend across the dialog (which would be its own border)."""
    tops = []
    for y in range(400):
        right = sum(1 for x in range(485, 595, 2) if pixel(body, x, y) == BUTTON_BORDER)
        if right < 40:
            continue
        left = sum(1 for x in range(300, 400, 2) if pixel(body, x, y) == BUTTON_BORDER)
        if left > 10:
            continue
        if not tops or y - tops[-1] > 3:
            tops.append(y)
    return tops


def dialog_top(body):
    """Top border row of the dialog box (a wide magenta run)."""
    for y in range(400):
        wide = sum(1 for x in range(100, 600, 4) if pixel(body, x, y) == BUTTON_BORDER)
        if wide > 80:
            return y
    return None


def is_protection_prompt(body):
    return (color_fraction(body, PURPLE) > 0.7
            and color_fraction(body, CYAN, step=199) > 0.002)


def is_protection_question(body):
    return (color_fraction(body, PURPLE) > 0.7
            and color_fraction(body, PINK, step=199) > 0.002)


def is_difficulty_select(body):
    return (color_fraction(body, PURPLE) > 0.7
            and color_fraction(body, DARKRED, step=199) > 0.002)


def has_menu(body):
    return len(button_rows(body)) == 4


def has_name_dialog(body):
    return len(button_rows(body)) == 2


def no_dialog(body):
    return dialog_top(body) is None


class Mi2Driver:
    def __init__(self, sock, chunks):
        self.sock = sock
        self.chunks = chunks

    def monitor(self, command, delay=0.15):
        self.sock.sendall((command + "\n").encode("ascii"))
        time.sleep(delay)

    def key(self, key, delay=0.15):
        self.monitor(f"sendkey {key}", delay)

    def click(self):
        self.monitor("mouse_button 1", 0.2)
        self.monitor("mouse_button 0", 0.5)

    def move_relative(self, dx, dy):
        while dx or dy:
            step_x = max(-100, min(100, dx))
            step_y = max(-100, min(100, dy))
            self.monitor(f"mouse_move {step_x} {step_y}", 0.03)
            dx -= step_x
            dy -= step_y

    def move_to(self, x, y):
        self.move_relative(-1000, -1000)
        self.move_relative(x, y)
        time.sleep(0.2)

    def cursor_position(self, before, after, old_pos):
        """Centroid of changed pixels between two dumps of a static screen.
        The diff contains the erased old cursor and the drawn new one; drop
        pixels near the known old position to keep only the new cluster."""
        xs = []
        ys = []
        for y in range(0, 400, 2):
            row = y * 640 * 3
            for x in range(0, 640, 2):
                o = row + x * 3
                if before[o:o + 3] != after[o:o + 3]:
                    if abs(x - old_pos[0]) < 25 and abs(y - old_pos[1]) < 25:
                        continue
                    xs.append(x)
                    ys.append(y)
        if not xs:
            return None
        return sum(xs) // len(xs), sum(ys) // len(ys)

    def click_at(self, x, y):
        """Closed-loop click: home, move, measure the real cursor position
        from screen diffs, and correct until within tolerance."""
        self.move_relative(-1000, -1000)
        time.sleep(0.2)
        base = self.screen()
        old = (0, 0)
        self.move_relative(x, y)
        time.sleep(0.2)
        for _ in range(4):
            now = self.screen()
            if base is None or now is None:
                break
            pos = self.cursor_position(base, now, old)
            if pos is None:
                break
            dx, dy = x - pos[0], y - pos[1]
            if abs(dx) <= 4 and abs(dy) <= 4:
                break
            base = now
            old = pos
            self.move_relative(dx, dy)
            time.sleep(0.2)
        self.click()

    def screen(self):
        try:
            os.unlink(STATE_PPM)
        except FileNotFoundError:
            pass
        self.monitor(f"screendump {STATE_PPM}", 0.7)
        if not os.path.exists(STATE_PPM):
            return None
        return load_ppm(STATE_PPM)

    def wait_screen(self, predicate, timeout, what):
        deadline = time.time() + timeout
        while time.time() < deadline:
            body = self.screen()
            if body is not None and predicate(body):
                return body
            time.sleep(1.0)
        raise RuntimeError(f"timed out waiting for {what}")

    def wait_serial(self, marker, timeout):
        deadline = time.time() + timeout
        while time.time() < deadline:
            output = b"".join(self.chunks).decode("utf-8", errors="replace")
            if marker in output:
                return True
            time.sleep(0.05)
        return False

    def click_button(self, body, index):
        tops = button_rows(body)
        self.click_at(535, tops[index] + 11)


def run_qemu_save_attempt():
    for path in [MONITOR, STATE_PPM, SCREEN_DIALOG, SCREEN_AFTER_OK]:
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
            "-vnc", unique_vnc_arg(),
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
        driver = Mi2Driver(sock, stdout_chunks)
        if not driver.wait_serial("C:\\>", 20):
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

        for key in ["c", "d", "spc", "m", "i", "2", "ret",
                    "m", "o", "n", "k", "e", "y", "2", "ret"]:
            driver.key(key, 0.08)

        driver.wait_screen(is_protection_prompt, 60, "copy-protection prompt")
        driver.key("ret", 1.5)
        driver.wait_screen(is_protection_question, 20, "copy-protection question")
        for key in ["1", "2", "3", "4", "ret"]:
            driver.key(key, 0.2)
        driver.wait_screen(is_difficulty_select, 20, "difficulty selection")
        driver.click_at(47, 127)             # CHECK ONE: full Monkey Island 2
        time.sleep(6)
        for _ in range(12):
            driver.key("esc", 0.5)
        time.sleep(4)

        # open the F5 menu; an ESC between attempts clears in-flight cutscenes
        menu = None
        for _ in range(6):
            driver.key("f5", 1.5)
            body = driver.screen()
            if body is not None and has_menu(body):
                menu = body
                break
            driver.key("esc", 1.0)
        if menu is None:
            raise RuntimeError("F5 menu did not appear")

        driver.click_button(menu, 0)         # Save
        dialog = driver.wait_screen(has_name_dialog, 10, "save-name dialog")
        with open(STATE_PPM, "rb") as src, open(SCREEN_DIALOG, "wb") as dst:
            dst.write(src.read())
        top = dialog_top(dialog)
        driver.click_at(75, top + 58)        # slot 2
        for key in ["a", "u", "t", "o"]:
            driver.key(key, 0.2)
        body = driver.screen()
        driver.click_button(body, 0)         # OK
        driver.wait_screen(no_dialog, 30, "save completion")
        time.sleep(3)

        # quit the game cleanly so all handles close before QEMU exits
        menu = None
        for _ in range(6):
            driver.key("f5", 1.5)
            body = driver.screen()
            if body is not None and has_menu(body):
                menu = body
                break
            driver.key("esc", 1.0)
        if menu is None:
            raise RuntimeError("F5 menu did not reappear for quit")
        with open(STATE_PPM, "rb") as src, open(SCREEN_AFTER_OK, "wb") as dst:
            dst.write(src.read())
        driver.click_button(menu, 3)         # Quit
        driver.key("y", 1.0)
        if not driver.wait_serial("C:\\MI2>", 30):
            raise RuntimeError("game did not exit to the shell prompt")
        time.sleep(1)

        driver.monitor("quit", 0.2)
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
        run_cmd(["python3", "scripts/build_games_hd_all.py"])
    before_entry, _ = read_file_from_image([b"MI2        ", b"SAVEGAME002"])
    if before_entry is not None:
        print("  FAIL: SAVEGAME.002 unexpectedly exists before save attempt")
        sys.exit(1)

    output = run_qemu_save_attempt()
    failed = False
    for marker in ["LainDOS booted", "LainDOS Shell", "C:\\MI2>monkey2"]:
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
        print(f"  FAIL: SAVEGAME.002 does not start with auto name prefix, "
              f"size={len(data)} sha256={digest}")
        failed = True
    elif len(data) < MIN_SAVE_SIZE:
        digest = hashlib.sha256(data).hexdigest()
        print(f"  FAIL: SAVEGAME.002 is unexpectedly small, "
              f"size={len(data)} sha256={digest}")
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
