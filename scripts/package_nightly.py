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
PACKAGE = BUILD / "laindos-monkey-demo-nightly.zip"
CHECKSUM = Path(str(PACKAGE) + ".sha256")


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


def main():
    if not IMG.is_file():
        print(f"Missing {IMG}; run make monkey-demo first.", file=sys.stderr)
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

    PACKAGE.unlink(missing_ok=True)
    CHECKSUM.unlink(missing_ok=True)
    with zipfile.ZipFile(PACKAGE, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(IMG, "laindos-monkey-demo.img")
        zf.writestr("README.txt", notes)

    digest = sha256(PACKAGE)
    CHECKSUM.write_text(f"{digest}  {PACKAGE.name}\n", encoding="ascii")
    print(f"Created {PACKAGE}")
    print(f"Created {CHECKSUM}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
