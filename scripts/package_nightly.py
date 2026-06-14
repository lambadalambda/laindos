#!/usr/bin/env python3
import hashlib
import os
import subprocess
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
IMG = BUILD / "shell_monkey.img"
INSTALLER_IMG = BUILD / "installer.img"
PACKAGE = BUILD / "laindos-monkey-demo-nightly.zip"
CHECKSUM = Path(str(PACKAGE) + ".sha256")
INSTALLER_PACKAGE = BUILD / "laindos-installer-nightly.zip"
INSTALLER_CHECKSUM = Path(str(INSTALLER_PACKAGE) + ".sha256")


def commit_id():
    sha = os.environ.get("GITHUB_SHA")
    if sha:
        return sha
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return "unknown"
    return result.stdout.strip()


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_package(image, arcname, package, checksum, notes):
    package.unlink(missing_ok=True)
    checksum.unlink(missing_ok=True)
    with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(image, arcname)
        zf.writestr("README.txt", notes)
    digest = sha256(package)
    checksum.write_text(f"{digest}  {package.name}\n", encoding="ascii")
    print(f"Created {package}")
    print(f"Created {checksum}")


def main():
    if not IMG.is_file():
        print(f"Missing {IMG}; run make monkey-demo first.", file=sys.stderr)
        return 1
    if not INSTALLER_IMG.is_file():
        print(f"Missing {INSTALLER_IMG}; run make installer first.", file=sys.stderr)
        return 1

    commit = commit_id()
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    notes = f"""LainDOS Monkey Island demo nightly

Source commit: {commit}
Generated: {generated}

Contents:
- laindos-monkey-demo.img: bootable 1.44 MB FAT12 floppy image

Run with QEMU:
qemu-system-i386 -drive file=laindos-monkey-demo.img,format=raw,if=floppy -boot order=a -device sb16

At the LainDOS shell prompt, run:
midemo
"""
    installer_notes = f"""LainDOS hard-disk installer nightly

Source commit: {commit}
Generated: {generated}

Contents:
- laindos-installer.img: bootable 1.44 MB FAT12 installer floppy image

The floppy boots LainDOS to A:\\>. Run INSTALL from that booted floppy to
format a blank hard disk or update an existing LainDOS FAT16 hard disk in
place. Do not launch A:\\INSTALL from a running C: boot; the installer refuses
that path because it writes the target disk directly through BIOS calls.

Example QEMU run with a raw hard-disk image:
qemu-system-i386 -drive file=laindos-installer.img,format=raw,if=floppy -drive file=harddisk.img,format=raw,if=ide,index=0,media=disk -boot order=a
"""

    write_package(IMG, "laindos-monkey-demo.img", PACKAGE, CHECKSUM, notes)
    write_package(
        INSTALLER_IMG,
        "laindos-installer.img",
        INSTALLER_PACKAGE,
        INSTALLER_CHECKSUM,
        installer_notes,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
