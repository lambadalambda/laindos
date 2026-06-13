# Current Status & Compatibility

What LainDOS implements today, and the compatibility decisions behind it.

## Current Status

- Boots FAT12 floppy images, raw FAT hard-disk images, simple MBR-partitioned FAT12/FAT16 hard disks, and floppy boots with an attached raw or partitioned FAT hard disk exposed as `C:`. Hard-disk boots expose the BIOS floppy as `A:` like real DOS, and floppy media changes are picked up both through the INT 13h change-line error on physical reads and through a real-DOS-style media check (with the 2-second rule) before cached FAT/root data is trusted; the volume is re-read and the drive's working directory resets to root.
- Loads `.COM` and MZ `.EXE` programs with PSP setup, relocation, terminate vectors, environment blocks, and MCB allocation; the arena ends at the BIOS INT 12h conventional-memory line (the EBDA stays with the BIOS) and the default allocation strategy is plain DOS first fit. A `.COM` owns the largest free block with SP entering at 0xFFFE and the zero word at [SP], exactly as real DOS loads them — `.COM` images carry no BSS, and era programs freely use the room past their file image. With the shell resident low, the first program loads above 64 KiB, so EXEPACK-era binaries start bare (LOADFIX stays bundled for layouts that need it).
- Provides a small shell with `AUTOEXEC.BAT`, current directory support, environment/PATH/BLASTER handling, and parent/child `EXEC` coverage including inherited child PSP handle tables.
- Implements the core DOS file APIs used by the current suite: open/read/write/seek/close, create/truncate, delete, rename, attributes, timestamps, disk free, FindFirst/FindNext, and writable FAT12/FAT16 paths.
- Mounts ISO-9660 CD-ROM media as read-only `D:` for file open/read/attributes/`EXEC`/overlay load through subdirectories, root and current-directory `FindFirst`/`FindNext`, and MSCDEX coverage including the INT 2Fh AX=1510h device-request path games use for CD audio: TOC-backed IOCTL Input control blocks (disc/track info, Q-channel, audio status, device status, volume size) and Play/Stop/Resume Audio commands served over ATAPI packets (Stop pauses with a resume point, and the request status word carries the spec's busy bit while audio plays — CD player UIs poll it to track playback), with the ATAPI transport brought up lazily when the BIOS EDD path won the mount. QEMU uses BIOS EDD reads; 86Box ATAPI profiles fall back to direct IDE packet reads.
- Provides a built-in `INT 33h` mouse service backed by PS/2 mouse packets, including movement, button press/release queries, callbacks (with cumulative mickey counters, as real drivers pass), scaling, edge clamping, driver info (AX=0024h reports an MS 8.20-style PS/2 driver), and state size/save/restore (AX=0015h-0017h).
- Provides minimal single-handle XMS APIs for game startup detection and backed XMS moves, using BIOS-reported extended memory capped at 15 MiB. Experimental backed EMS support exists behind `ENABLE_EMS=1` but is hidden in default builds.
- Builds and runs the bundled shell-boot Monkey Island demo floppy.
- Runs the full VGA Monkey Island image when `vendor/monkey_full.zip` is present.
- Runs the full Monkey Island 2: LeChuck's Revenge with working in-game save and load, verified end to end by the vendor-gated `make test-mi2-save` smoke.
- Installs Stunt Island from its source media through the in-game installer and boots the installed game to its interactive startup prompts under QEMU, verified by the vendor-gated `make test-stunt-island-smoke`.
- Runs Norton Commander 5.5 with startup, child-launch, file-copy, rename/delete, and mkdir/rmdir smokes, and Shortline to an active game screen, when the local archives are present.
- Installs Micro Machines 2 through its real four-floppy Codemasters installer (language selection, SHR unpacking, three disk swaps) and launches the installed game through DOS/4GW to its interactive copy-protection screen, verified by the vendor-gated `make test-mm2-smoke`.
- Installs Wing Commander through its real three-floppy Origin installer (drive selection, two disk swaps picked up by the media check) and runs it past the Claw Marks copy-protection quiz, the Vega campaign menu, the simulator name entry, and into the animated bar scene, verified by the vendor-gated `make test-wc-smoke`.
- Installs The Settlers II Gold Edition from its CD data track through the real Blue Byte installer and launches the installed game through DOS/4GW to its 640x480 VESA main menu, verified by the vendor-gated `make test-settlers2-smoke`. Under QEMU the menu's timer-driven input pump never runs (an emulator interaction of the Civilization PIT class); under 86Box the game is fully playable.
- Runs the Simon the Sorcerer demo (AGOS engine) to its interactive in-game scene with verb interface and mouse cursor, verified by the vendor-gated `make test-simon-smoke`.
- Runs Sid Meier's Civilization to its startup menus and animating VGA intro (CIV.EXE is EXEPACK-compressed and needs a 64 KiB-plus load address; with DOS-style largest-block COM loading the first program clears that line bare, and the bundled `LOADFIX.COM` stays for layouts that need it), verified by the vendor-gated `make test-civ-smoke`. Under the headless 86Box build the same image reaches the title menu (`make test-civ-86box`); under QEMU further progress is blocked by an emulator PIT-timing interaction that also reproduces under FreeDOS.
- Runs Ascendancy under 86Box and under a locally patched QEMU with the `SAHF` condition-code fix documented in `docs/qemu-sahf-ccop.patch`.
- Runs Wolfenstein 3D shareware to visible first-level gameplay when `vendor/wolf3dsw.zip` is present.
- Provides vendor-gated `make test-sammax-cd-files`, `make test-sammax-cd-start`, `make test-sammax-cd-setmuse`, `make test-sammax-cd-setmuse-save`, `make test-sammax-cd-install`, `make test-sammax-cd-install-select`, `make test-sammax-cd-dig`, and `make test-normality-install` smokes for the Sam & Max Hit the Road CD data track from its cue/bin archive. The Normality smoke drives the Gremlin installer end to end (its copy phase runs `COPY`/`MD` through `COMSPEC /C`) and launches the installed demo.
- `make test` currently runs the automated QEMU regression ladder and passes `148/148` tests.

## Scope

LainDOS focuses on practical game compatibility rather than abstract DOS completeness.

Implemented or in active use:

- Real-mode boot, FAT filesystem access, and DOS API dispatch.
- FAT12, FAT16, raw HD images, and simple MBR-partitioned FAT12/FAT16 images.
- DOS memory allocation through MCBs.
- Minimal XMS detection, query, single-block allocation, handle-release behavior, and XMS block moves.
- Basic device names and console I/O.
- Minimal shell, batch startup, and PATH lookup.
- Built-in mouse driver behavior for games that call `INT 33h` directly.

Still out of scope unless a target forces it:

- Full `COMMAND.COM` compatibility.
- Native DOS device driver loading or `CONFIG.SYS` processing.
- Full XMS multi-handle/reallocation/HMA behavior, full multi-handle EMS/named-handle behavior, UMB/HMA, load-high behavior, SHARE, redirectors, printing, or networking.
- Implementing sound hardware in DOS; games talk to emulator-provided hardware such as `-device sb16` directly, with `-device adlib` added only for games that need a separate OPL/AdLib probe path such as Wolf3D and the Sam & Max CD launcher. LainDOS supplies a conventional `BLASTER=A220 I5 D1 H5 P330 T6` environment variable so games can find the Sound Blaster-compatible device.
- General DPMI/VCPI services. DOS extenders that manage protected mode themselves may work if their real-mode DOS calls and CPU assumptions are satisfied.

## Compatibility Notes

- `INT 21h AH=30h` returns DOS 5.00. The API surface now covers the 5.0-era feature set (handle API, EXEC including load-only, allocation strategies, XMS with the kernel resident in the HMA), and several CD-era games refuse to start on anything older. The true-version call (AX=3306h) also advertises the DOS-in-HMA flag. If a specific title ever needs 3.x semantics, add a SETVER-style per-program override rather than lowering the global version.
- LainDOS uses serial output heavily. Use `-serial stdio` or a serial log for reproducible traces.
- If 86Box progresses but QEMU stalls, check `docs/emulator_workflows.md` and `docs/debug_log.md` before changing DOS behavior.
- The current local QEMU workaround is saved as `docs/qemu-sahf-ccop.patch` and is committed separately in the sibling QEMU clone as `06cbfb3 target/i386: mark SAHF flags as materialized`.
