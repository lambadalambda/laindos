#!/usr/bin/env python3
import os
import sys

from fatlib import FatImage, entry_cluster, entry_size
from testlib import build_dir, check_markers, run_cmd, run_serial_image


BUILDDIR = build_dir()
WORKDIR = os.path.join(BUILDDIR, "cd_shellcopy_large")
BOOT = os.path.join(WORKDIR, "boot.bin")
KERNEL = os.path.join(WORKDIR, "kernel.bin")
PROGRAM = os.path.join(WORKDIR, "cdshcopy.com")
SHELL = os.path.join(WORKDIR, "shell.com")
IMG = os.path.join(WORKDIR, "cd_shellcopy_large.img")
ISO = os.path.join(WORKDIR, "cd_shellcopy_large.iso")
NORM_SIZE = 990711
FILLER_SIZE = 450 * 4096
TWEEN_SIZE = 1152512
TWEENWT_SIZE = 1152512
TIMEOUT = 120

ISO_FILES = [
    ("DEMOS/NORMALIT/ENGLISH.DAT", 227848, 0x11),
    ("DEMOS/NORMALIT/HMIDET.DRV", 52856, 0x22),
    ("DEMOS/NORMALIT/HMIDRV.DRV", 188711, 0x33),
    ("DEMOS/NORMALIT/HMIMDRV.DRV", 100647, 0x44),
    ("DEMOS/NORMALIT/READ.ME", 1777, 0x55),
    ("DEMOS/NORMALIT/INSTALL.EXE", 151904, 0x66),
    ("DEMOS/NORMALIT/INSTALL.INI", 53765, 0x77),
    ("DEMOS/NORMALIT/NORM.EXE", NORM_SIZE, 0x88),
    ("DEMOS/NORMALIT/FILLER.BIN", FILLER_SIZE, 0x99),
    ("DEMOS/NORMALIT/GFX/LOOPAPLO.MGL", 17759, 0xA1),
    ("DEMOS/NORMALIT/GFX/LOOPAPR.MGL", 47959, 0xA2),
    ("DEMOS/NORMALIT/GFX/MAPLO.MGL", 41255, 0xA3),
    ("DEMOS/NORMALIT/GFX/MAPSCRN.MGL", 152011, 0xA4),
    ("DEMOS/NORMALIT/GFX/OPTSCR.MGL", 188002, 0xA5),
    ("DEMOS/NORMALIT/GFX/OPTSCRLO.MGL", 46971, 0xA6),
    ("DEMOS/NORMALIT/GFX/PLRSTPAP.MGL", 5761, 0xA7),
    ("DEMOS/NORMALIT/GFX/PRPAPLO.MGL", 2237, 0xA8),
    ("DEMOS/NORMALIT/GFX/TWEEN.DAT", TWEEN_SIZE, 0xAA),
    ("DEMOS/NORMALIT/GFX/TWEENWT.DAT", TWEENWT_SIZE, 0xAB),
]


def destination_path(iso_path):
    name = iso_path.rsplit("/", 1)[1]
    if iso_path.startswith("DEMOS/NORMALIT/GFX/"):
        return f"NORMINC/GFX/{name}"
    return f"NORMINC/{name}"


def pattern_data(size, seed):
    return bytes((i * 37 + (i >> 8) + (i >> 16) + seed) & 0xFF for i in range(size))


def build_artifacts():
    os.makedirs(WORKDIR, exist_ok=True)
    iso_args = []
    for iso_path, size, seed in ISO_FILES:
        host_path = os.path.join(WORKDIR, iso_path.replace("/", "_"))
        with open(host_path, "wb") as f:
            f.write(pattern_data(size, seed))
        iso_args.append(f"{iso_path}={host_path}")
    run_cmd(["python3", "scripts/mkiso.py", ISO, *iso_args])
    run_cmd(["nasm", "-DFAT16=1", "-f", "bin", "src/boot.asm", "-o", BOOT])
    run_cmd(["nasm", '-DBOOT_FILE="CDSHCOPYCOM"', "-f", "bin", "src/kernel.asm", "-o", KERNEL])
    run_cmd(["nasm", "-f", "bin", "tests/programs/cdshcopy.asm", "-o", PROGRAM])
    run_cmd(["python3", "scripts/build_shell_com.py", SHELL])
    run_cmd(["python3", "scripts/mkimage.py", "--format=hd160m", BOOT, KERNEL, IMG, PROGRAM, SHELL])


def verify_image_file(img, path, size, seed):
    entry = img.find(path)
    if entry is None:
        print(f"  FAIL: {path} missing from disk image")
        return False
    actual_size = entry_size(entry)
    if actual_size != size:
        print(f"  FAIL: {path} size {actual_size}, expected {size}")
        return False
    chain_bytes = len(img.cluster_chain(entry_cluster(entry))) * img.bps * img.spc
    if chain_bytes < size:
        print(f"  FAIL: {path} cluster chain only covers {chain_bytes} bytes")
        return False
    data = img.read_chain(entry_cluster(entry), size)
    expected = pattern_data(size, seed)
    if data != expected:
        for off, (got, want) in enumerate(zip(data, expected)):
            if got != want:
                print(f"  FAIL: {path} differs at offset {off}: got {got:02X}, expected {want:02X}")
                break
        return False
    print(f"  PASS: {path} matches the CD source pattern")
    return True


def verify_copied_files():
    img = FatImage.from_file(IMG)
    ok = True
    for iso_path, size, seed in ISO_FILES:
        ok = verify_image_file(img, destination_path(iso_path), size, seed) and ok
    return ok


def main():
    build_artifacts()
    output = run_serial_image(
        IMG,
        TIMEOUT,
        drive_opts="if=ide,index=0,media=disk",
        boot_order="c",
        extra_args=("-drive", f"file={ISO},format=raw,if=ide,index=1,media=cdrom,readonly=on"),
    )
    ok = check_markers(
        output,
        required=("PASS: CDSHCOPY", "Program exited, code=00", "HALT"),
        forbidden=("FAIL:", "File error", "File not found", "EXC ", "INT 21h AH="),
        output_label="CD shell copy QEMU serial output",
    )
    if not verify_copied_files():
        ok = False
    if not ok:
        sys.exit(1)
    print("\nCD shell large-copy test passed.")


if __name__ == "__main__":
    main()
