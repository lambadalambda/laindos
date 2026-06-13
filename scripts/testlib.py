#!/usr/bin/env python3
import atexit
import os
import signal
import socket
import subprocess
import sys
import threading
import tempfile
import time


DEFAULT_FAIL_MARKERS = ("FAIL:", "EXC ", "INT 21h AH=")
DEFAULT_STOP_MARKERS = ("HALT",)
DEFAULT_QEMU_VGA = "std,retrace=precise"
REPO_ROOT = os.path.dirname(os.path.dirname(__file__))
DEFAULT_QEMU = os.path.abspath(os.path.join(
    REPO_ROOT,
    "..",
    "qemu-ascendancy",
    "build-asc",
    "qemu-system-i386-unsigned",
))


def build_dir():
    return os.environ.get("LAINDOS_TEST_BUILD_DIR", os.path.join(REPO_ROOT, "build"))


def qemu_binary():
    configured = os.environ.get("LAINDOS_QEMU")
    if configured:
        if os.sep in configured:
            return os.path.abspath(configured)
        return configured
    if os.path.exists(DEFAULT_QEMU):
        return DEFAULT_QEMU
    return "qemu-system-i386"


def qemu_vga():
    return os.environ.get("LAINDOS_QEMU_VGA", DEFAULT_QEMU_VGA)


def qemu_sb16_silent_args():
    return ["-audiodev", "none,id=laindos_noaudio", "-device", "sb16,audiodev=laindos_noaudio"]


def qemu_sb16_adlib_silent_args():
    return [*qemu_sb16_silent_args(), "-device", "adlib,audiodev=laindos_noaudio"]


def qemu_args(args):
    args = list(args)
    if args and args[0] == "qemu-system-i386":
        args[0] = qemu_binary()
    return args


def run_cmd(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        print(f"Command failed: {' '.join(str(c) for c in cmd)}", file=sys.stderr)
        sys.exit(result.returncode)


def build_nasm_test_image(builddir, img, kernel, boot_file, program_source, program_name, extra_files=(), kernel_defines=()):
    os.makedirs(builddir, exist_ok=True)
    boot = os.path.join(builddir, "boot.bin")
    program = os.path.join(builddir, program_name)
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    kernel_cmd = ["nasm", f'-DBOOT_FILE="{boot_file}"']
    kernel_cmd.extend(kernel_defines)
    kernel_cmd.extend(["-f", "bin", "src/kernel.asm", "-o", kernel])
    run_cmd(kernel_cmd)
    run_cmd(["nasm", "-f", "bin", program_source, "-o", program])
    run_cmd(["python3", "scripts/mkimage.py", boot, kernel, img, program, *extra_files])
    return program


def build_simple_test_image(label, boot_file, programs, builddir=None, extra_files=(), kernel_defines=()):
    """Build a test image with one or more programs.

    `programs` is a list of (source_path, output_name) tuples; each source is
    assembled with `nasm -f bin` into the test build directory and added to
    the disk image. Returns the image path.
    """
    if builddir is None:
        builddir = build_dir()
    os.makedirs(builddir, exist_ok=True)
    img = os.path.join(builddir, f"{label}.img")
    kernel = os.path.join(builddir, f"{label}_kernel.bin")
    boot = os.path.join(builddir, "boot.bin")
    run_cmd(["nasm", "-DFAT12=1", "-f", "bin", "src/boot.asm", "-o", boot])
    kernel_cmd = ["nasm", f'-DBOOT_FILE="{boot_file}"']
    kernel_cmd.extend(kernel_defines)
    kernel_cmd.extend(["-f", "bin", "src/kernel.asm", "-o", kernel])
    run_cmd(kernel_cmd)
    output_paths = []
    for source, name in programs:
        out = os.path.join(builddir, name)
        run_cmd(["nasm", "-f", "bin", source, "-o", out])
        output_paths.append(out)
    run_cmd(["python3", "scripts/mkimage.py", boot, kernel, img, *output_paths, *extra_files])
    return img


def run_simple_serial_test(label, boot_file, programs, required=(),
                           forbidden=DEFAULT_FAIL_MARKERS, extra_files=(),
                           kernel_defines=(), timeout=10, drive_opts="if=floppy",
                           pass_message=None, builddir=None, allow_timeout=False):
    """Build a test image, run it in QEMU over serial, and verify markers.

    Convenience wrapper around `build_simple_test_image` + `run_serial_image`
    + `check_markers`. Exits the process with a non-zero status on any
    missing required marker or unexpected forbidden marker.
    """
    img = build_simple_test_image(label, boot_file, programs,
                                 builddir=builddir, extra_files=extra_files,
                                 kernel_defines=kernel_defines)
    output = run_serial_image(img, timeout=timeout, drive_opts=drive_opts,
                              allow_timeout=allow_timeout)
    passed = check_markers(output, required=required, forbidden=forbidden,
                           output_label=f"{label} QEMU serial output")
    if not passed:
        sys.exit(1)
    print(f"\n{pass_message or (label + ' test passed.')}")


def run_serial_image(img, timeout=10, qemu="qemu-system-i386", drive_opts="if=floppy",
                     allow_timeout=False, boot_order="a", extra_args=()):
    drive = f"file={img},format=raw,{drive_opts}" if drive_opts else f"file={img},format=raw"
    output, timed_out = run_qemu_capture([
        qemu,
        "-drive", drive,
        "-boot", f"order={boot_order}",
        *extra_args,
        "-serial", "stdio",
        "-monitor", "none",
        "-nographic",
    ], timeout)
    if timed_out and not allow_timeout:
        print(f"FAIL: QEMU ran for {timeout}s without reaching a stop marker (hang?)")
        print("--- QEMU serial output ---")
        print(output)
        print("--- end ---")
        sys.exit(1)
    return output


def remove_if_exists(path):
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass


def read_stream(stream, chunks):
    try:
        while True:
            data = os.read(stream.fileno(), 4096)
            if not data:
                return
            chunks.append(data)
    except OSError:
        # QEMU teardown can close the pipe while this reader is blocked.
        return


def start_qemu(args, env=None):
    proc = subprocess.Popen(
        qemu_args(args),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )
    stdout_chunks = []
    stderr_chunks = []
    stdout_thread = threading.Thread(target=read_stream, args=(proc.stdout, stdout_chunks), daemon=True)
    stderr_thread = threading.Thread(target=read_stream, args=(proc.stderr, stderr_chunks), daemon=True)
    stdout_thread.start()
    stderr_thread.start()
    atexit.register(kill_qemu_at_exit, proc)
    return proc, stdout_chunks, stderr_chunks, (stdout_thread, stderr_thread)


def kill_qemu_at_exit(proc):
    if proc.poll() is None:
        proc.kill()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            return


def chunks_contain(chunks, markers):
    if not markers:
        return False
    output = b"".join(chunks)
    return any(marker.encode() in output for marker in markers)


class ChunkScanner:
    """Incremental marker scan over a growing chunk list. Each poll only
    appends new chunks and searches the unseen tail (plus a needle-sized
    overlap), keeping repeated polling linear in total output."""

    def __init__(self, chunks, *marker_groups):
        self.chunks = chunks
        self.index = 0
        self.buf = bytearray()
        self.scanned = 0
        self.groups = [tuple(m.encode() for m in group) for group in marker_groups]
        self.overlap = max((len(n) for g in self.groups for n in g), default=1) - 1

    def poll(self):
        """Return a tuple of booleans, one per marker group."""
        while self.index < len(self.chunks):
            self.buf += self.chunks[self.index]
            self.index += 1
        start = max(0, self.scanned - self.overlap)
        window = bytes(self.buf[start:])
        self.scanned = len(self.buf)
        return tuple(any(n in window for n in group) for group in self.groups)


def wait_for_output(chunks, marker, timeout=10, stop_markers=DEFAULT_FAIL_MARKERS + DEFAULT_STOP_MARKERS):
    scanner = ChunkScanner(chunks, (marker,), stop_markers)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        found, stopped = scanner.poll()
        if found:
            return True
        if stopped:
            return False
        time.sleep(0.02)
    return False


def open_monitor(path, timeout=8):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    deadline = time.time() + timeout
    while True:
        try:
            sock.connect(path)
            break
        except OSError:
            if time.time() > deadline:
                sock.close()
                raise
            time.sleep(0.1)
    try:
        sock.recv(4096)
    finally:
        sock.settimeout(None)
    return sock


def send_monitor_command(sock, command, delay=0.0):
    sock.sendall(f"{command}\n".encode())
    if delay:
        time.sleep(delay)


def monitor_output_path(path):
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    if os.path.isabs(path):
        return os.path.relpath(path, os.getcwd())
    return path


def send_monitor_key(sock, key, delay=0.15):
    send_monitor_command(sock, f"sendkey {key}", delay)


def send_monitor_text(sock, text, delay=0.15, keymap=None):
    keys = {" ": "spc", "\\": "backslash", ".": "dot", "-": "minus"}
    if keymap:
        keys.update(keymap)
    for ch in text:
        send_monitor_key(sock, keys.get(ch, ch.lower()), delay)


def monitor_screendump(sock, path, delay=1):
    send_monitor_command(sock, f"screendump {monitor_output_path(path)}")
    if delay:
        time.sleep(delay)


def monitor_quit(sock, proc, timeout=5):
    try:
        send_monitor_command(sock, "quit")
    except OSError:
        pass
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.send_signal(signal.SIGTERM)
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def stop_qemu(proc, grace=3):
    if proc.poll() is not None:
        return
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


def ppm_stats(path):
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        if f.readline().strip() != b"P6":
            return None
        dims = f.readline().split()
        if len(dims) != 2:
            return None
        if f.readline().strip() != b"255":
            return None
        pixels = f.read()
    colors = set()
    nonblack = 0
    for i in range(0, len(pixels), 3):
        color = pixels[i:i+3]
        colors.add(color)
        if color != b"\x00\x00\x00":
            nonblack += 1
    return len(colors), nonblack


def framebuffer_active(path, label="framebuffer", min_colors=8, min_nonblack=1000):
    stats = ppm_stats(path)
    if stats is None:
        print(f"  FAIL: missing valid {label} screendump")
        return False
    colors, nonblack = stats
    if colors >= min_colors and nonblack > min_nonblack:
        print(f"  PASS: {label} active ({colors} colors, {nonblack} nonblack pixels)")
        return True
    print(f"  FAIL: {label} inactive ({colors} colors, {nonblack} nonblack pixels)")
    return False


def check_markers(output, required=(), forbidden=DEFAULT_FAIL_MARKERS, output_label="QEMU serial output", dump_on_failure=True):
    failed = False
    for marker in required:
        if marker in output:
            print(f"  PASS: found '{marker}'")
        else:
            print(f"  FAIL: missing '{marker}'")
            failed = True
    for marker in forbidden:
        if marker in output:
            print(f"  FAIL: unexpected '{marker}'")
            failed = True
    if failed and dump_on_failure:
        print(f"\n--- {output_label} ---")
        print(output)
        print("--- end ---")
    return not failed


def collect_output(stdout_chunks, stderr_chunks, threads):
    for thread in threads:
        thread.join(timeout=1)
    output = b"".join(stdout_chunks).decode("utf-8", errors="replace")
    err = b"".join(stderr_chunks).decode("utf-8", errors="replace")
    if err:
        print(err, end="", file=sys.stderr)
    return output


def finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout=10, stop_markers=DEFAULT_STOP_MARKERS, fail_markers=DEFAULT_FAIL_MARKERS):
    deadline = time.monotonic() + timeout
    timed_out = False
    scanner = ChunkScanner(stdout_chunks, fail_markers, stop_markers)
    while proc.poll() is None:
        failed, stopped = scanner.poll()
        if failed or stopped:
            time.sleep(0.05)
            break
        if time.monotonic() >= deadline:
            timed_out = True
            break
        time.sleep(0.02)
    stop_qemu(proc)
    return collect_output(stdout_chunks, stderr_chunks, threads), timed_out


def run_qemu_capture(args, timeout=10, stop_markers=DEFAULT_STOP_MARKERS, fail_markers=DEFAULT_FAIL_MARKERS):
    proc, stdout_chunks, stderr_chunks, threads = start_qemu(args)
    return finish_qemu(proc, stdout_chunks, stderr_chunks, threads, timeout, stop_markers, fail_markers)

def parse_text_screen(data):
    """Parse a 4000-byte B800 text-memory dump into 25 stripped rows."""
    rows = []
    for row in range(25):
        chars = []
        for col in range(80):
            ch = data[(row * 80 + col) * 2]
            chars.append(chr(ch) if 32 <= ch < 127 else " ")
        rows.append("".join(chars).rstrip())
    return rows


def read_text_screen(path):
    """Rows of a saved B800 dump joined by newlines ("" if missing)."""
    if not os.path.exists(path):
        return ""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 4000:
        return ""
    return "\n".join(parse_text_screen(data))


def monitor_text_screen(sock, path, delay=0.3):
    """pmemsave the B800 text screen through the QEMU monitor and parse it."""
    remove_if_exists(path)
    send_monitor_command(sock, f"pmemsave 0xb8000 4000 {monitor_output_path(path)}", delay=delay)
    return read_text_screen(path)


def monitor_text_screen_attrs(sock, path, delay=0.3):
    """Like monitor_text_screen but with per-row attribute runs for
    highlight detection ("Rnn [start-end:0xattr] ... |text|")."""
    remove_if_exists(path)
    send_monitor_command(sock, f"pmemsave 0xb8000 4000 {monitor_output_path(path)}", delay=delay)
    if not os.path.exists(path):
        return ""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 4000:
        return ""
    lines = []
    text_rows = parse_text_screen(data)
    for row in range(25):
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
        lines.append(f"R{row:02d} {runs} |{text_rows[row]}|")
    return "\n".join(lines)

def unique_vnc_display():
    """A VNC display number unlikely to collide between concurrent runs."""
    return 100 + (os.getpid() % 800)


def unique_vnc_arg():
    return f"127.0.0.1:{unique_vnc_display()}"


def unique_monitor_socket(name):
    """A per-process QEMU monitor socket path for game/CD tests."""
    return os.path.join(tempfile.gettempdir(),
                        f"laindos-{name}-{os.getpid()}.sock")
