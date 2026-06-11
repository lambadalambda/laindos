"""Helpers for driving the headless 86Box build over its localhost RPC.

The headless build is the SDL (QT=OFF) frontend from the local 86Box
checkout's laindos-headless branch, run with SDL's dummy video driver and
the opt-in HTTP RPC enabled via the 86BOX_RPC_PORT environment variable.
Endpoints: /status, /key?scan=<n>[&down=0|1], /screenshot,
/monitor?cmd=<urlencoded>, /exit. Serial output reaches the process
stdout through a profile's `serial1_device = stdio`, so testlib's
start_qemu/ChunkScanner machinery works unchanged.
"""
import os
import time
import urllib.request

from testlib import start_qemu

DEFAULT_HEADLESS_86BOX = "build/86box/build-headless/src/86Box.app/Contents/MacOS/86Box"
DEFAULT_ROMS = os.path.expanduser("~/Library/Application Support/net.86box.86Box/roms")

# AT set-1 make codes for the characters the shell choreography needs.
SCANCODES = {
    "1": 0x02, "2": 0x03, "3": 0x04, "4": 0x05, "5": 0x06,
    "6": 0x07, "7": 0x08, "8": 0x09, "9": 0x0A, "0": 0x0B,
    "-": 0x0C, "=": 0x0D,
    "q": 0x10, "w": 0x11, "e": 0x12, "r": 0x13, "t": 0x14,
    "y": 0x15, "u": 0x16, "i": 0x17, "o": 0x18, "p": 0x19,
    "a": 0x1E, "s": 0x1F, "d": 0x20, "f": 0x21, "g": 0x22,
    "h": 0x23, "j": 0x24, "k": 0x25, "l": 0x26, ";": 0x27,
    "z": 0x2C, "x": 0x2D, "c": 0x2E, "v": 0x2F, "b": 0x30,
    "n": 0x31, "m": 0x32, ",": 0x33, ".": 0x34, "/": 0x35,
    " ": 0x39, "\\": 0x2B,
}
KEY_ENTER = 0x1C
KEY_ESC = 0x01
KEY_F1 = 0x3B
KEY_LSHIFT = 0x2A


def headless_86box():
    return os.environ.get("LAINDOS_86BOX_HEADLESS", DEFAULT_HEADLESS_86BOX)


def rom_path():
    return os.environ.get("LAINDOS_86BOX_ROMS", DEFAULT_ROMS)


def unique_rpc_port():
    return 18000 + (os.getpid() % 800)


def start_86box(profile, port, floppy=None, extra_args=()):
    """Launch the headless 86Box on a profile; returns testlib's
    (proc, stdout_chunks, stderr_chunks, threads) tuple."""
    env = dict(os.environ)
    env["SDL_VIDEODRIVER"] = "dummy"
    env["86BOX_RPC_PORT"] = str(port)
    args = [headless_86box(), "-P", os.path.abspath(profile), "-R", rom_path(), "-N"]
    if floppy:
        args.extend(["-I", f"a:{os.path.abspath(floppy)}"])
    args.extend(extra_args)
    return start_qemu(args, env=env)


def rpc(port, path, timeout=15):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=timeout) as resp:
        return resp.read().decode("utf-8", "replace")


def wait_rpc(port, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if rpc(port, "/status").strip() == "ok":
                return True
        except OSError:
            pass
        time.sleep(0.5)
    return False


def press(port, scan, delay=0.1):
    rpc(port, f"/key?scan={scan}")
    time.sleep(delay)


def press_shifted(port, scan, delay=0.1):
    rpc(port, f"/key?scan={KEY_LSHIFT}&down=1")
    rpc(port, f"/key?scan={scan}")
    rpc(port, f"/key?scan={KEY_LSHIFT}&down=0")
    time.sleep(delay)


def type_text(port, text, delay=0.1):
    for ch in text:
        if ch == ":":
            press_shifted(port, SCANCODES[";"], delay)
        elif ch.isupper():
            press_shifted(port, SCANCODES[ch.lower()], delay)
        else:
            press(port, SCANCODES[ch], delay)


def type_command(port, command, delay=0.1):
    type_text(port, command, delay)
    press(port, KEY_ENTER, delay)


def press_f1_through_cmos(port, boot_wait=12):
    """Fresh profiles stop at the Award 'CMOS checksum error / Press F1'
    prompt on first boot; clear it."""
    time.sleep(boot_wait)
    press(port, KEY_F1)


def latest_screenshot(port, profile, settle=1.5):
    """Trigger a screenshot and return the newest PNG path in the profile."""
    shots = os.path.join(profile, "screenshots")
    before = set(os.listdir(shots)) if os.path.isdir(shots) else set()
    rpc(port, "/screenshot")
    time.sleep(settle)
    if not os.path.isdir(shots):
        return None
    new = [name for name in os.listdir(shots) if name not in before]
    candidates = new or list(os.listdir(shots))
    if not candidates:
        return None
    return max((os.path.join(shots, name) for name in candidates), key=os.path.getmtime)


def rpc_exit(port):
    try:
        rpc(port, "/exit")
    except OSError:
        pass


def png_stats(path):
    """(distinct colors, nonblack pixels) for an 8-bit RGB/RGBA PNG,
    matching testlib.ppm_stats semantics for 86Box screenshots."""
    import struct
    import zlib

    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    pos = 8
    idat = b""
    width = height = depth = color_type = None
    while pos + 8 <= len(data):
        length, typ = struct.unpack(">I4s", data[pos:pos + 8])
        pos += 8
        chunk = data[pos:pos + length]
        pos += length + 4
        if typ == b"IHDR":
            width, height, depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
    if depth != 8 or color_type not in (2, 6):
        return None
    bpp = 3 if color_type == 2 else 4
    raw = zlib.decompress(idat)
    stride = width * bpp
    prev = bytearray(stride)
    colors = set()
    nonblack = 0
    pos = 0
    for _ in range(height):
        filt = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if filt == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif filt == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif filt == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif filt == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        for x in range(0, stride, bpp):
            pixel = (line[x], line[x + 1], line[x + 2])
            colors.add(pixel)
            if pixel != (0, 0, 0):
                nonblack += 1
        prev = line
    return (len(colors), nonblack)
