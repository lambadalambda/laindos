# Triage Stunt Island Fresh-Boot Memory Failure

## Summary

Stunt Island reportedly refused to start because it complained about memory even on a fresh boot. Local media now shows the fresh direct launch has enough conventional memory; the startup blocker was LainDOS mishandling 65,536-byte XMS moves during the game's extended-memory cache path.

## Requirements

- Build or document a local Stunt Island repro image without committing proprietary game files.
- Capture the exact memory error text and launch path on a fresh boot.
- Compare LainDOS reported conventional memory, largest executable block, environment size, and MCB layout against a known-good DOS run where practical.
- Check whether the failure depends on XMS/EMS detection, EXE `MinAlloc`/`MaxAlloc`, PSP top-of-memory fields, or allocation strategy behavior.
- Add focused memory or loader regression coverage for any identified compatibility gap.

## Acceptance Criteria

- The fresh-boot memory complaint is checked against local media and the actual startup blocker is explained.
- Stunt Island starts, or the remaining memory requirement is documented with a concrete missing DOS behavior.
- `make test` passes after any implementation change.

## Notes

- Reported symptom: "complains about memory even on fresh boot".
- This may overlap with the process-memory-release issue only if repeated launches make the symptom worse; the initial report says fresh boot also fails.
- The Stunt Island manual says the game needs 570K free RAM and its troubleshooting guide describes the message as similar to `Not enough memory. Stunt Island requires 570,000 bytes free.`
- Fresh LainDOS shell probing currently reports largest executable program size `560 K (574384 bytes)`, so LainDOS is above 570,000 decimal bytes but below 570 KiB.
- `vendor/002514_stunt_island.7z` provided six floppy images. The generated local install under `build/stunt_source_hd.img` reaches `C:\STUNTISL` and launches `STUNT`.
- Direct fresh launch reaches `Caching data 15360K in extended memory`, so the conventional-memory complaint is not reproduced with the local install.
- A no-XMS kernel copy skips the cache path and reaches `DISNEY INTRO REEL 15`, isolating the XMS cache path.
- Added XMS regression coverage for a single 65,536-byte conventional-to-XMS move, independent BIOS readback from the requested XMS physical address, and a 65,536-byte XMS-to-conventional move across a 64K boundary. Before the DWORD-length fix `scripts/test_xms.py` failed with `FAIL: XMS MOVE 64K TO`; before the follow-up physical-address fix it failed with `FAIL: XMS MOVE 64K BIOS CMP`.
- LainDOS XMS `AH=0Bh` now accepts DWORD lengths by validating the full 32-bit extent, converting handle offsets to physical addresses once per chunk, and copying in `0xFFFE`-byte chunks.
- With the XMS fix, the XMS-enabled Stunt launch reaches the same `DISNEY INTRO REEL 15` frame. The remaining post-intro black screen appears separate from the fresh-boot memory complaint.
