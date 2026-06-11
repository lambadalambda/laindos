#!/usr/bin/env python3
"""Civilization under headless 86Box: the QEMU PIT-stall cross-check.

Boots the generated Civilization hard-disk image on the headless RPC
86Box build (docs/86box-rpc.patch), launches the game through LOADFIX,
skips the intro, and verifies it reaches the title menu — the screen
QEMU never reaches because of its PIT interaction with the game's
INT 08 hook. Requires the vendor archive, the headless 86Box binary
(LAINDOS_86BOX_HEADLESS or the default build path), and a ROM set.
"""
import os
import sys
import time

from testlib import check_markers, collect_output, run_cmd, stop_qemu
import box86lib as box

ARCHIVE = "vendor/sid-meiers-civilization-au.zip"
IMG = "build/civ_hd.img"
RUN_IMG = "build/civ_86box_run.img"
PROFILE = "build/civ_86box/profile"
MENU_DEADLINE = 240
MENU_MIN_COLORS = 35
MENU_MIN_NONBLACK = 30000

PROFILE_CFG = """[General]
emu_build_num = 9001

[Machine]
cpu_family = pentium_p54c
cpu_multi = 1.5
cpu_speed = 75000000
cpu_use_dynarec = 1
fpu_type = internal
machine = p54tp4xe
mem_size = 8192

[Video]
gfxcard = s3_trio32_pci

[Input devices]
keyboard_type = keyboard_at
mouse_type = ps2

[Network]
net_01_link = 0

[Storage controllers]
fdc = none
hdc_1 = ide_pci

[Ports (COM & LPT)]
serial1_device = stdio

[Virtual Console (COM) #1]
mode = 0

[Hard disks]
hdd_01_parameters = 63, 16, 65, 0, ide
hdd_01_fn = {img}
hdd_01_ide_channel = 0:0
hdd_01_speed = ramdisk
"""


def build_profile():
    import shutil
    shutil.rmtree(PROFILE, ignore_errors=True)
    os.makedirs(PROFILE, exist_ok=True)
    shutil.copyfile(IMG, RUN_IMG)
    with open(os.path.join(PROFILE, "86box.cfg"), "w", encoding="ascii") as f:
        f.write(PROFILE_CFG.format(img=os.path.abspath(RUN_IMG)))


def main():
    if not os.path.exists(ARCHIVE):
        print(f"Missing {ARCHIVE}", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(box.headless_86box()):
        print(f"Missing headless 86Box binary: {box.headless_86box()}", file=sys.stderr)
        print("Build it per docs/emulator_workflows.md or set LAINDOS_86BOX_HEADLESS.", file=sys.stderr)
        sys.exit(1)
    if not os.path.isdir(box.rom_path()):
        print(f"Missing 86Box ROM set: {box.rom_path()}", file=sys.stderr)
        sys.exit(1)
    run_cmd(["python3", "scripts/build_civ_hd.py"])
    build_profile()

    port = box.unique_rpc_port()
    proc, stdout_chunks, stderr_chunks, threads = box.start_86box(PROFILE, port)

    def out_text():
        return b"".join(stdout_chunks).decode("utf-8", "replace")

    failure = None
    try:
        if not box.wait_rpc(port, 30):
            raise RuntimeError("86Box RPC never came up")
        deadline = time.time() + 60
        while time.time() < deadline and "C:\\>" not in out_text():
            # first boot of a fresh profile waits at the CMOS prompt
            box.press(port, box.KEY_F1)
            time.sleep(3)
        if "C:\\>" not in out_text():
            raise RuntimeError("no LainDOS shell prompt over 86Box serial")
        print("  PASS: LainDOS shell prompt over 86Box serial")
        box.type_command(port, "cd civ")
        time.sleep(1)
        box.type_command(port, "loadfix civ")
        time.sleep(10)
        for _ in range(3):  # graphics, sound, input menus: take option 1
            box.press(port, box.SCANCODES["1"], delay=2.5)
        time.sleep(4)
        box.press(port, box.KEY_ESC, delay=1)
        box.press(port, box.KEY_ESC, delay=1)
        deadline = time.time() + MENU_DEADLINE
        stats = None
        while time.time() < deadline:
            if "R6003" in out_text():
                raise RuntimeError("game crashed with R6003 under 86Box")
            shot = box.latest_screenshot(port, PROFILE)
            stats = box.png_stats(shot) if shot else None
            if stats is not None:
                colors, nonblack = stats
                if colors >= MENU_MIN_COLORS and nonblack >= MENU_MIN_NONBLACK:
                    print(f"  PASS: title-menu screen ({colors} colors, {nonblack} nonblack pixels)")
                    break
            time.sleep(10)
        else:
            raise RuntimeError(f"no title-menu screen within {MENU_DEADLINE}s; last stats: {stats}")
        box.rpc_exit(port)
    except RuntimeError as exc:
        failure = str(exc)
    finally:
        time.sleep(1)
        stop_qemu(proc)

    output = collect_output(stdout_chunks, stderr_chunks, threads)
    failed = failure is not None
    if failure is not None:
        print(f"  FAIL: {failure}")
    failed = not check_markers(
        output,
        required=("LainDOS booted",),
        forbidden=("EXC ", "R6003", "Packed file is corrupt"),
        dump_on_failure=False,
    ) or failed
    if failed:
        print("\n--- 86Box serial output ---")
        print(output)
        print("\nCivilization 86Box cross-check failed.")
        sys.exit(1)
    print("Civilization 86Box cross-check passed.")


if __name__ == "__main__":
    main()
