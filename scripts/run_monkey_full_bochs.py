#!/usr/bin/env python3
"""Build and boot the full VGA Monkey Island image in Bochs."""
import os
import shutil
import subprocess
import sys

BOCHSRC = "build/monkey_full.bochsrc"
SOURCE_IMG = "build/monkey_full.img"
LOG = "build/bochs_monkey_full.log"
SERIAL_LOG = "build/bochs_serial.log"


def run(cmd):
    result = subprocess.run(cmd)
    if result.returncode != 0:
        sys.exit(result.returncode)


def write_bochsrc(display, img):
    os.makedirs("build", exist_ok=True)
    if os.path.exists(LOG):
        os.remove(LOG)
    if os.path.exists(SERIAL_LOG):
        os.remove(SERIAL_LOG)
    with open(BOCHSRC, "w", encoding="ascii") as f:
        f.write(f"""megs: 32
display_library: {display}
boot: disk
ata0: enabled=1, ioaddr1=0x1f0, ioaddr2=0x3f0, irq=14
ata0-master: type=disk, path={img}, mode=flat, cylinders=20, heads=16, spt=63
com1: enabled=1, mode=file, dev={SERIAL_LOG}
mouse: enabled=1, type=ps2
log: {LOG}
panic: action=fatal
error: action=report
info: action=report
debug: action=ignore
""")


def log_has_panic():
    if not os.path.exists(LOG):
        return False
    with open(LOG, "r", encoding="ascii", errors="replace") as f:
        return "PANIC" in f.read()


def serial_has_boot_marker():
    if not os.path.exists(SERIAL_LOG):
        return False
    with open(SERIAL_LOG, "r", encoding="ascii", errors="replace") as f:
        return "MiniDOS booted" in f.read()


def smoke(seconds):
    proc = subprocess.Popen(["bochs", "-q", "-f", BOCHSRC])
    try:
        code = proc.wait(timeout=seconds)
        if code != 0:
            return code
        if log_has_panic():
            print("Bochs smoke failed: panic found in log")
            return 1
        if not serial_has_boot_marker():
            print("Bochs smoke failed: missing 'MiniDOS booted' serial marker")
            return 1
        return 0
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        if log_has_panic():
            print("Bochs smoke failed: panic found in log")
            return 1
        if not serial_has_boot_marker():
            print("Bochs smoke failed: missing 'MiniDOS booted' serial marker")
            return 1
        print(f"Bochs smoke ran for {seconds} seconds and reached 'MiniDOS booted'")
        return 0


def smoke_seconds():
    if "--smoke-seconds" not in sys.argv:
        return None
    index = sys.argv.index("--smoke-seconds")
    try:
        seconds = int(sys.argv[index + 1])
    except (IndexError, ValueError):
        print("usage: run_monkey_full_bochs.py [--dry-run] [--smoke-seconds N]  (env: BOCHS_DISPLAY=sdl2|nogui)")
        sys.exit(2)
    if seconds < 1:
        print("error: --smoke-seconds must be >= 1")
        sys.exit(2)
    return seconds


def main():
    dry_run = "--dry-run" in sys.argv
    seconds = smoke_seconds()
    display = os.environ.get("BOCHS_DISPLAY", "sdl2")
    if not dry_run and shutil.which("bochs") is None:
        print("error: bochs not found in PATH")
        sys.exit(127)
    run(["python3", "scripts/build_monkey_full.py"])
    img = f"build/monkey_full_bochs_{os.getpid()}.img"
    shutil.copyfile(SOURCE_IMG, img)
    write_bochsrc(display, img)
    print(f"Bochs config: {BOCHSRC}")
    print(f"Bochs image: {img}")
    if dry_run:
        return
    try:
        if seconds is not None:
            sys.exit(smoke(seconds))
        run(["bochs", "-q", "-f", BOCHSRC])
    finally:
        if os.path.exists(img):
            os.remove(img)


if __name__ == "__main__":
    main()
