# Guard CD-ROM drive against FAT mutation calls

## Summary

AH=41h delete (`src/kernel/int21.inc:3473-3481`), AH=56h rename (4621-4632), AH=39h mkdir (2218-2230), and AH=3Ah rmdir (2313-2327) lack the CD-ROM drive guard that create (2403-2404), open (2666-2667), and attrs (3809-3810) have. For a CD drive, `load_active_volume_buffers` skips loading FAT/ROOT buffers (`src/kernel.asm:1196-1197`), so these handlers search the previous FAT drive's stale root/FAT images in RAM — e.g. `DEL D:FOO.TXT` can match a leftover name from drive A's buffer, stamp 0xE5 into it, and attempt a sector write to the CD.

## Requirements

- Return error 5 up front from delete/rename/mkdir/rmdir when the resolved drive is `DRIVE_TYPE_CDROM`, mirroring the create/open guard.

## Acceptance Criteria

- Test on the CD test image: DEL/REN/MD/RD against D: fail with AX=5 and the previously active FAT drive's buffers remain valid (a follow-up read on A: succeeds); `PASS:` markers.
- Existing CD tests pass.
