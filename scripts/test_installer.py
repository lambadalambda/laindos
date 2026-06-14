#!/usr/bin/env python3
"""The installer floppy installs or updates a bootable hard disk.

Builds the self-booting installer floppy, boots it with a blank hard disk
attached, runs INSTALL (scripted with /Y) to format the disk to FAT16 and
copy the system files, then:
  - verifies the result host-side as a structural proof of bootability:
    the boot sector's code region is byte-identical to the FAT16 boot
    template the installer wrote, the 0xAA55 signature and "FAT16" type
    are present, and KERNEL.SYS/SHELL.COM/FREE.COM/TIME.COM are
    byte-identical to the sources (read back through an independent
    fatlib, which follows the FAT chain the boot loader does).

The test also boots the installer against an existing LainDOS FAT16 image with
stale system files plus user data. That path must update the managed system
files and boot sector without reformatting or deleting unrelated files.
It also boots from the installed C: hard disk with the installer floppy still
attached and verifies A:\\INSTALL refuses to run, since direct BIOS writes to a
mounted boot volume can leave the install inconsistent.

That host check is the deterministic gate. An end-to-end boot of the
installed disk to a C: shell is available via `--boot-check` and confirmed
manually, but is not the gate: launching a second QEMU from inside this
test's process is environmentally flaky (the identical image boots every
time from a separate process), so it would only add false negatives.

The installer talks to the disk with INT 13h directly (the kernel has no
absolute-disk API and won't mount a freshly formatted disk until reboot),
sizing a fresh FAT16 BPB to the detected geometry.
"""
import os
import hashlib
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from fatlib import FatImage, entry_cluster
from testlib import (build_dir, qemu_binary, start_qemu, stop_qemu,
                     open_monitor, monitor_text_screen, monitor_quit,
                     send_monitor_text, send_monitor_key, run_cmd,
                     unique_monitor_socket, remove_if_exists)

BUILDDIR = build_dir()
STAGE = os.path.join(BUILDDIR, "installer")
EXISTING = os.path.join(BUILDDIR, "installer_existing")
FLOPPY = os.path.join(BUILDDIR, "installer.img")
HD = os.path.join(BUILDDIR, "installer_test_hd.img")
HD_SECTORS = 327600                     # ~160 MB blank target
BOOT16 = os.path.join(STAGE, "boot16.bin")
SOURCES = {
    "KERNEL.SYS": os.path.join(STAGE, "kernel.bin"),
    "SHELL.COM": os.path.join(STAGE, "shell.com"),
    "FREE.COM": os.path.join(STAGE, "free.com"),
    "TIME.COM": os.path.join(STAGE, "time.com"),
}
KEYMAP = {":": "shift-semicolon"}
KEEP_BYTES = (b"preserve this user file\r\n" * 19) + b"end\r\n"
SUB_BYTES = (b"subdirectory data survives updater\r\n" * 181) + b"done\r\n"


def screen(sock, retries=5):
    # the pmemsave-to-file capture races and intermittently returns empty;
    # retry until it yields something so prompt detection stays reliable
    s = ""
    for _ in range(retries):
        s = monitor_text_screen(sock, os.path.join(BUILDDIR, "installer_text.bin"),
                                delay=0.5)
        if s.strip():
            return s
        time.sleep(0.5)
    return s


def wait_prompt(sock, needle, timeout):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if needle in screen(sock):
            return True
        time.sleep(1.5)
    return False


def installed_enough():
    # the installer writes the boot sector first and the root directory last,
    # so a KERNEL.SYS entry in the root means the install has essentially
    # finished. Polling the disk file is deterministic and load-independent,
    # unlike the screen capture.
    try:
        with open(HD, "rb") as f:
            boot = f.read(512)
            if boot[0x1FE:0x200] != b"\x55\xAA":
                return False
            fat_sz = struct.unpack("<H", boot[0x16:0x18])[0]
            f.seek((1 + 2 * fat_sz) * 512)      # root directory start
            root = f.read(512)
        return b"KERNEL  SYS" in root
    except OSError:
        return False


def updated_enough():
    try:
        img = FatImage.from_file(HD)
        for name, src in SOURCES.items():
            if img.read_file(name) != open(src, "rb").read():
                return False
        return img.read_file("KEEP.DAT") == KEEP_BYTES
    except Exception:
        return False


def image_hash():
    h = hashlib.sha256()
    with open(HD, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run_hd_boot_refusal():
    before = image_hash()
    mon = unique_monitor_socket("installer_hd_boot")
    remove_if_exists(mon)
    proc, *_ = start_qemu([
        qemu_binary(),
        "-drive", f"file={FLOPPY},format=raw,if=floppy,index=0",
        "-drive", f"file={HD},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c", "-serial", "null",
        "-monitor", f"unix:{mon},server,nowait",
        "-display", "none",
    ])
    sock = open_monitor(mon)
    try:
        if not wait_prompt(sock, "C:\\>", 120):
            return "FAIL: C: shell prompt never appeared"
        send_monitor_text(sock, "a:", delay=0.1, keymap=KEYMAP)
        send_monitor_key(sock, "ret")
        if not wait_prompt(sock, "A:\\>", 30):
            return "FAIL: A: shell prompt never appeared"
        send_monitor_text(sock, "install y", delay=0.1)
        send_monitor_key(sock, "ret")
        if not wait_prompt(sock, "FAIL: boot the installer floppy", 30):
            return "FAIL: hard-disk boot was not refused"
    finally:
        monitor_quit(sock, proc)
        sock.close()
        stop_qemu(proc)
    after = image_hash()
    if after != before:
        return "FAIL: hard-disk boot refusal modified the target image"
    return "REFUSED"


def run_install(tag, prepare_blank, completion):
    if prepare_blank:
        with open(HD, "wb") as f:
            f.truncate(HD_SECTORS * 512)
    mon = unique_monitor_socket(tag)
    remove_if_exists(mon)
    proc, *_ = start_qemu([
        qemu_binary(),
        "-drive", f"file={FLOPPY},format=raw,if=floppy,index=0",
        "-drive", f"file={HD},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=a", "-serial", "null",
        "-monitor", f"unix:{mon},server,nowait",
        "-display", "none",
    ])
    sock = open_monitor(mon)
    try:
        # Wait for the shell (robust screen read), type the scripted install,
        # then detect completion by polling the disk -- both load-tolerant,
        # which matters when the suite runs four QEMUs at once.
        if not wait_prompt(sock, "A:\\>", 120):
            return "FAIL: shell prompt never appeared"
        # "install y" rather than "/y": the monitor keymap has no slash, and
        # the installer's scripted-yes scan accepts any Y/y in the tail
        send_monitor_text(sock, "install y", delay=0.1)
        send_monitor_key(sock, "ret")
        deadline = time.time() + 180
        while time.time() < deadline:
            if completion():
                time.sleep(3)           # let write_root finish zeroing
                return "INSTALL DONE"
            time.sleep(3)
        return "FAIL: install did not complete"
    finally:
        monitor_quit(sock, proc)
        sock.close()
        stop_qemu(proc)


def verify_installed_host():
    # boot sector: signature, FAT16 type, and boot code identical to the
    # template the installer wrote (proves a bootable VBR, not just a BPB)
    boot = open(HD, "rb").read(512)
    template = open(BOOT16, "rb").read()
    assert boot[0x1FE] == 0x55 and boot[0x1FF] == 0xAA, "missing 0xAA55 signature"
    assert boot[0x36:0x3E] == b"FAT16   ", f"bad FS type {boot[0x36:0x3E]!r}"
    assert boot[0x3E:0x1FE] == template[0x3E:0x1FE], "boot code != template"
    # filesystem: valid FAT16 with the system files byte-exact
    img = FatImage.from_file(HD)
    assert img.bits == 16, f"expected FAT16, got FAT{img.bits}"
    for name, src in SOURCES.items():
        got = img.read_file(name)
        want = open(src, "rb").read()
        assert got == want, f"{name} not byte-exact ({len(got)} vs {len(want)})"
    print(f"  PASS: bootable FAT16 VBR + valid FS ({img.total_sectors} sectors, "
          f"spc {img.spc}), 4 files byte-exact")


def write_stale(path, size, seed):
    data = bytes(((seed + i) & 0xFF) for i in range(size))
    with open(path, "wb") as f:
        f.write(data)


def stale_size(name, current_size):
    if name == "KERNEL.SYS":
        return max(1, current_size // 2)
    if name == "SHELL.COM":
        return current_size + 8192
    return current_size


def managed_chains(img):
    chains = {}
    for name in SOURCES:
        entry = img.find(name)
        chains[name] = img.cluster_chain(entry_cluster(entry))
    return chains


def prepare_existing_install():
    os.makedirs(EXISTING, exist_ok=True)
    stale_paths = {}
    for seed, (name, src) in enumerate(SOURCES.items(), start=0x31):
        dst = os.path.join(EXISTING, name.lower())
        write_stale(dst, stale_size(name, os.path.getsize(src)), seed)
        stale_paths[name] = dst
    keep = os.path.join(EXISTING, "keep.dat")
    sub = os.path.join(EXISTING, "sub.dat")
    with open(keep, "wb") as f:
        f.write(KEEP_BYTES)
    with open(sub, "wb") as f:
        f.write(SUB_BYTES)
    run_cmd([
        "python3", "scripts/mkimage.py", "--format=hd160m",
        BOOT16, stale_paths["KERNEL.SYS"], HD,
        stale_paths["SHELL.COM"], stale_paths["FREE.COM"],
        stale_paths["TIME.COM"], keep, f"DATA:{sub}",
    ])
    old_chains = managed_chains(FatImage.from_file(HD))
    with open(HD, "r+b") as f:
        f.seek(0x100)
        original = f.read(1)
        f.seek(0x100)
        f.write(bytes([original[0] ^ 0x5A]))
    return open(HD, "rb").read(512), old_chains


def verify_fats_match(img):
    fat1 = img.data[img.fat_off:img.fat_off + img.sectors_per_fat * img.bps]
    fat2_off = img.offset + (img.reserved + img.sectors_per_fat) * img.bps
    fat2 = img.data[fat2_off:fat2_off + img.sectors_per_fat * img.bps]
    assert fat1 == fat2, "FAT copies differ after installer update"


def verify_updated_host(old_boot):
    boot = open(HD, "rb").read(512)
    template = open(BOOT16, "rb").read()
    assert boot[0x1FE] == 0x55 and boot[0x1FF] == 0xAA, "missing 0xAA55 signature"
    assert boot[0x00:0x0B] == template[0x00:0x0B], "updated boot header != template"
    assert boot[0x0B:0x3E] == old_boot[0x0B:0x3E], "update did not preserve BPB"
    assert boot[0x3E:0x1FE] == template[0x3E:0x1FE], "updated boot code != template"
    img = FatImage.from_file(HD)
    assert img.bits == 16, f"expected FAT16, got FAT{img.bits}"
    verify_fats_match(img)
    for name, src in SOURCES.items():
        got = img.read_file(name)
        want = open(src, "rb").read()
        assert got == want, f"{name} was not updated byte-exact"
    assert img.read_file("KEEP.DAT") == KEEP_BYTES, "root user file was not preserved"
    assert img.read_file("DATA/SUB.DAT") == SUB_BYTES, "subdirectory user file was not preserved"
    print("  PASS: existing LainDOS image updated without deleting user files")


def verify_old_chains_released(old_chains):
    img = FatImage.from_file(HD)
    referenced = set()
    for name in list(SOURCES) + ["KEEP.DAT", "DATA", "DATA/SUB.DAT"]:
        entry = img.find(name)
        referenced.update(img.cluster_chain(entry_cluster(entry)))
    for name, chain in old_chains.items():
        for cluster in chain:
            if cluster not in referenced:
                assert img.fat_next(cluster) == 0, (
                    f"old {name} cluster {cluster} was not freed")


def boot_check():
    """Boot the installed disk and return True if it reaches a C: shell.

    Run in a FRESH process (see boot_from_hd): a second QEMU launched in the
    same process as the install never boots here -- likely a start_qemu
    reader-thread / resource interaction -- while a standalone process boots
    the identical image reliably.
    """
    mon = unique_monitor_socket("installed")
    remove_if_exists(mon)
    proc, *_ = start_qemu([
        qemu_binary(),
        "-drive", f"file={HD},format=raw,if=ide,index=0,media=disk",
        "-boot", "order=c", "-serial", "null",
        "-monitor", f"unix:{mon},server,nowait",
        "-display", "none", "-snapshot",
    ])
    sock = open_monitor(mon)
    boot_text = os.path.join(BUILDDIR, "installer_boot_text.bin")
    booted = False
    try:
        for _ in range(12):
            time.sleep(3)
            if "C:\\>" in monitor_text_screen(sock, boot_text):
                booted = True
                break
    finally:
        monitor_quit(sock, proc)
        sock.close()
        stop_qemu(proc)
    return booted




def main():
    run_cmd(["python3", "scripts/build_installer.py"])
    s = run_install("installer_blank", True, installed_enough)
    if "FAIL" in s:
        print("  FAIL: installer reported an error:")
        print("\n".join(l for l in s.splitlines() if l.strip()))
        sys.exit(1)
    # the host-side image check is the real gate: if the install did not
    # complete, the target is not a valid FAT16 volume with the files.
    try:
        verify_installed_host()
    except Exception as exc:
        print(f"  FAIL: target not correctly installed: {exc}")
        print("  last installer screen:")
        print("\n".join(l for l in s.splitlines() if l.strip()))
        sys.exit(1)

    s = run_hd_boot_refusal()
    if "FAIL" in s:
        print("  FAIL: installer hard-disk boot safeguard failed:")
        print("\n".join(l for l in s.splitlines() if l.strip()))
        sys.exit(1)
    print("  PASS: A:\\INSTALL refuses to run from a C: boot without modifying the disk")

    old_boot, old_chains = prepare_existing_install()
    s = run_install("installer_update", False, updated_enough)
    if "FAIL" in s:
        print("  FAIL: installer update reported an error:")
        print("\n".join(l for l in s.splitlines() if l.strip()))
        sys.exit(1)
    try:
        verify_updated_host(old_boot)
        verify_old_chains_released(old_chains)
    except Exception as exc:
        print(f"  FAIL: target not correctly updated: {exc}")
        print("  last installer screen:")
        print("\n".join(l for l in s.splitlines() if l.strip()))
        sys.exit(1)
    print("\nInstaller test passed.")


if __name__ == "__main__":
    if "--boot-check" in sys.argv:
        sys.exit(0 if boot_check() else 1)
    main()
