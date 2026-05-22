# Phase 18: Boot Full VGA Monkey Island

## Summary

Boot the full VGA version of The Secret of Monkey Island from `vendor/monkey_full.zip` under LainDOS and reach the point where real save/load behavior can be validated.

## Requirements

- Inspect the full-game archive layout and identify the executable, data files, and total image size requirements.
- Build a reproducible full-game disk image from `vendor/monkey_full.zip` without committing vendor game data.
- Add the smallest storage support needed to boot the full game, such as a larger FAT image or basic hard-disk support if floppy images are insufficient.
- Preserve the existing Monkey demo, MI2 demo, shell, and writable FAT regressions.
- Record blockers and compatibility findings in `docs/debug_log.md`.

## Acceptance Criteria

- A script can build a full Monkey Island image from `vendor/monkey_full.zip`.
- QEMU can boot LainDOS with the full-game image and launch the full Monkey Island executable.
- The run reaches an observable game screen or a clearly documented next missing DOS/BIOS/API blocker.
- Existing `make test`, Monkey demo smoke, and MI2 demo smoke still pass.

## Notes

- The archive is gitignored under `vendor/`; do not commit extracted game files.
- The full VGA version is expected to be larger than current floppy demo media and may require extending image-building and disk-access support.
- Initial bring-up uses an unpartitioned 10 MB FAT12 hard-disk-style image (`--format=hd10m`) booted as BIOS drive `80h`.
- Image parameters: 20,160 sectors, 8 sectors per cluster, 224 root entries, 8 sectors per FAT, CHS 20 cylinders / 16 heads / 63 sectors per track, media byte `0xF8`, drive byte `0x80`.
- `scripts/test_monkey_full.py` currently verifies boot, `MONKEY.EXE` load, and `INT 33h AX=0000` mouse initialization in serial output.
- Interactive visible gameplay is verified. Full save/load validation remains under Phase 9 because `F5` did not open the save menu in the user's full VGA run.
