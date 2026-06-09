# Support CD-ROM install and startup for Sam & Max Hit the Road

## Summary

Add enough CD-ROM support for LainDOS to install and start Sam & Max Hit the Road from the local cue/bin image in `vendor/`.

## Requirements

- Keep the first implementation slice driven by small bespoke CD images before using the full vendor image.
- Expose a read-only CD-ROM drive letter through DOS file APIs.
- Implement the minimal MSCDEX-compatible probes needed by target programs.
- Preserve existing FAT drive behavior and default regression coverage.
- Add vendor-gated smoke coverage for the Sam & Max image once the focused CD-ROM path works.

## Acceptance Criteria

- A focused smoke can boot LainDOS with a small CD image attached and read a file from the CD drive through DOS APIs.
- The smoke verifies CD drive selection and directory enumeration for the CD drive.
- Writes or mutating directory operations against the CD drive fail safely as read-only.
- Sam & Max setup can be launched from the vendor cue/bin image under LainDOS.
- Sam & Max can be installed or otherwise prepared enough to start under LainDOS.
- Relevant docs/debug notes are updated.

## Notes

- Started on 2026-06-09 after adding Norton Commander filesystem smokes.
- The vendor archive is `vendor/Bestseller Games Gold 3 - Sam & Max Hit the Road.zip`.
- The cue sheet has one `MODE1/2352` data track followed by four audio tracks.
- Initial scope should ignore Redbook audio unless the installer/startup path requires MSCDEX audio/control calls.
- Focused generated-ISO smokes now cover BIOS CD reads, read-only `D:` file open/read/`EXEC`/overlay load through subdirectories, drive selection, root/subdirectory/current-directory `FindFirst`/`FindNext`, and MSCDEX install/drive/version probes. Vendor-gated smokes now normalize the Sam & Max MODE1/2352 cue/bin data track, read `D:\SAMNMAX` files, start `D:\SAMNMAX\SAMNMAX.EXE`, verify the SETMUSE sound-card list, pass the sound-driver prompt, and verify an active framebuffer; the issue remains open for installer/preparation coverage and any deeper MSCDEX device-driver calls the target requires.
