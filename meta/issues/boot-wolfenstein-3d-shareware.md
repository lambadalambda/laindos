# Boot Wolfenstein 3D Shareware

## Summary

Add Wolfenstein 3D shareware as a compatibility target using `vendor/wolf3dsw.zip`. The image builds and starts under 86Box from the all-games hard disk. Under QEMU, the default VGA retrace mode stalls on a black framebuffer in a real-mode `0x3DA` status polling loop, while `-vga std,retrace=precise` reaches visible Wolf3D UI. Default XMS support now gets QEMU to first-level gameplay with visible textures in repeated smoke probes; EMS remains experimental and hidden by default.

## Requirements

- Keep `scripts/build_wolf3d.py` able to build `build/wolf3d.img` from `vendor/wolf3dsw.zip`.
- Include the shareware files in `build/games_hd_all.img` under `WOLF3D` so the target is easy to try in 86Box.
- Determine whether the first blocker is LainDOS behavior or emulator VGA/timer behavior.
- If it is a LainDOS issue, implement the smallest compatibility fix needed to get past the black-screen startup loop.
- Continue toward the original memory-manager goal only after Wolf3D reaches the point where it probes or requires XMS/EMS behavior.

## Acceptance Criteria

- `python3 scripts/build_wolf3d.py` builds a bootable image.
- Wolfenstein 3D reaches visible startup/game UI under the standard patched-QEMU workflow or a documented emulator-specific workaround.
- Any required new DOS, BIOS-adjacent, timer, VGA, XMS, or EMS behavior has a focused regression or documented smoke test.
- The issue documents whether Wolf3D actually requires XMS/EMS for this shareware path or only benefits from it.

## Notes

- Initial probe: `build/wolf3d.img` boots, prints `EXE loaded`, has no `EXC ` or unhandled `INT 21h AH=` marker, and the framebuffer remains black after 20 seconds.
- `scripts/build_games_hd_all.py` installs the required shareware files under `WOLF3D` from the same local archive.
- In 86Box, `build/games_hd_all.img` reaches the Wolf3D hardware detection/startup screen from `C:\WOLF3D\WOLF3D.EXE`.
- The 86Box startup screen detects mouse and Sound Blaster, and reaches visible UI without EMS/XMS indicators, so XMS/EMS is not required for the initial shareware startup path.
- Running Wolf3D under real DOS 4.0 from `/Users/lainsoykaf/repos/MS-DOS/build/dos40.img` in QEMU with the Wolf3D files exposed as a FAT hard disk reproduces the same all-black framebuffer hash as LainDOS: `f3ee47648d6ba080ffab59f9c5cc84d66a44ee6de07c5fa3edbe222e95021062`.
- The real-DOS/QEMU stopped state also has `DX=0x03DA` and `IF=0`, so the default-QEMU blocker is independent of LainDOS.
- DOS tracing before the stall shows vector setup and memory resize calls, but no Wolf3D data-file opens yet.
- Monitor sampling shows execution around a VGA status polling loop reading port `0x3DA` near physical `0x2d966`.
- The expected first visible screen is Wolf3D's hardware detection screen with memory, mouse, joystick, AdLib, Sound Blaster, and Sound Source indicators.
- A standalone VGA status probe shows QEMU's port `0x3DA` status changes while interrupts are enabled and the BIOS tick advances, but stays fixed at `0x09` while `IF=0` in a tight `CLI` loop. Wolf3D's sampled loop is in that `IF=0` state waiting for bit 0 to clear.
- With explicit `-vga std,retrace=dumb`, the standalone `CLI` probe still sees the fixed `0x09` value; with `-vga std,retrace=precise`, it sees status transitions and passes.
- With `WOLF3D_VGA='std,retrace=precise' python3 build/run_wolf3d_probe.py`, the standalone Wolf3D image reaches visible output: `colors=79 nonblack=233588`.
- `make run` and the interactive mise QEMU run tasks default to `std,retrace=precise` through `QEMU_VGA` / `LAINDOS_QEMU_VGA`, including `run-games-hd-all`.
- Minimal XMS support covers `INT 2Fh AX=4300h/4310h` plus XMS entry functions for version, query, allocate, free, move, lock, unlock, and handle info. It reports an 8 MiB single block; the earlier 1 MiB report made Ascendancy's DOS/4GW path fail with error 1307. `scripts/test_xms.py` covers detection, query, full-block allocation, conventional-to-XMS-to-conventional data movement, and move bounds rejection.
- Experimental EMS support covers `EMMXXXX0`, `INT 67h` status, version, free pages, one handle allocation/free, page count, and backed page-frame mapping when compiled with `ENABLE_EMS=1`. `scripts/test_ems.py` covers this path explicitly.
- After the XMS/EMS work, `WOLF3D_VGA='std,retrace=precise' python3 build/run_wolf3d_probe.py` shows EMS and XMS green through `1000`; MAIN is green through `288` and dark at `320`. `python3 build/run_wolf3d_keyprobe.py` reaches the Wolf3D title screen after pressing a key.
- XMS now has a backed single-handle move path using BIOS extended-memory block moves. EMS has a backed single-handle page-frame path at `9000h`, but the frame is not protected from DOS allocations because reserving it made Wolf3D fail its conventional-memory check. A user run with EMS enabled later reached gameplay and then crashed with `EXC 06 at 9999:9CA4`, matching that collision risk.
- Probed `0xB000`, `0xC000`, `0xD000`, and `0xE000` as non-overlapping EMS frames; all failed the EMS backing regression under QEMU.
- With default EMS hidden, `python3 build/run_wolf3d_smoke.py` reaches floor 1 with visible wall/floor textures and no `EXC `, unhandled `INT 21h AH=`, or `PML_MapEMS` marker. Three repeated short smoke runs reached the screenshot point cleanly.
- `-icount shift=auto` did not change the `IF=0` VGA status behavior.
- The first QEMU-only blocker is therefore before the sound probe UI can draw, and is likely VGA-status/timing emulation rather than XMS/EMS or sound hardware probing.
