# Triage Stunt Island Post-Intro Black Screen

## Summary

After the XMS cache-path fix, Stunt Island reached the Disney intro but the QEMU run went to a black screen afterward. The QEMU black screen was isolated to Stunt entering a BIOS-tick wait with IF clear after a `FindFirst`; LainDOS now returns from DOS-style interrupt helpers with IF set, which advances QEMU to the same prompt class seen in 86Box. The remaining prompt input behavior matched a missing `INT 33h AX=0006h` mouse-release query path, and manual retest confirmed prompt mouse clicks work after adding release-query support.

## Requirements

- Reproduce the post-intro black screen under QEMU and capture serial output, screenshots, CPU/register samples, timer state, and interrupt-flag state near the black-screen loop.
- Compare the same generated Stunt image under 86Box and capture the competition-prompt input behavior.
- Determine whether the QEMU black screen is caused by QEMU video/timing behavior, LainDOS DOS services, Stunt's XMS cache contents, or input/mouse handling. Result: it was an IF/timer compatibility issue at `INT 21h AH=4Eh` return time, not video rendering or XMS cache contents.
- Probe the competition-prompt click failure by checking mouse button delivery, callbacks, coordinate scaling, and whether keyboard alternatives work. Result: keyboard `Y`/`N` works, hover changes the cursor, and the built-in mouse driver lacked `INT 33h AX=0006h` release data.
- Keep proprietary Stunt media and generated hard-disk images under `vendor/` or `build/` untracked.

## Acceptance Criteria

- The QEMU post-intro black screen has a concrete root class: LainDOS DOS-return interrupt-flag compatibility.
- If the prompt click failure is a LainDOS input issue, add a focused regression or compatibility fix; if not, document the emulator/input setup needed. Result: `tests/programs/mousecb.asm` now covers press/release callbacks and `AX=0006h` release-query data.
- Relevant automated tests and at least one Stunt smoke/manual comparison are documented after any implementation change.

## Notes

- The completed fresh-boot memory triage found enough conventional memory for the local install and fixed LainDOS XMS `AH=0Bh` 65,536-byte move handling.
- QEMU with the pre-fix generated image showed `Caching data 15360K in extended memory`, then `DISNEY INTRO REEL 15`, then a black screen.
- User manual test of the same image in 86Box went further to an image asking `do you want to enter the competition`; mouse movement worked and keyboard `Y`/`N` activated the prompt, but clicking the Yes/No buttons did not activate them before `INT 33h AX=0006h` support.
- CPU sampling of the QEMU black screen showed real-mode game code looping at `1033:6291` with `IF=0`, `ES=0040`, and BIOS tick `40:6C` frozen in `cmpw %es:0x6c,%bx; je`.
- A gdb force-IF probe advanced QEMU immediately to a nonblack competition prompt-like screen; breakpoint probes showed IF was already clear before Stunt's `INT 21h AH=4Eh`, so the compatibility fix is for LainDOS DOS returns to set IF in the saved return frame.
- `tests/programs/findedge.asm` now covers `FindFirst` returning with IF set even after a caller-side `cli`; it failed before the fix with `FAIL: FINDEDGE FIND IF` and passes after the fix.
- Disposable patched Stunt smoke with `build/stunt_if_hd.img` reaches nonblack screen stats `(208, 217732)` at 5s and 15s instead of the prior black-screen stats `(1, 0)`.
- `tests/programs/mousetest.asm` now covers reset-time empty `INT 33h AX=0006h` release queries through `scripts/test_mouse.py`.
- `tests/programs/mousecb.asm` now covers left-button press/release callbacks plus `INT 33h AX=0005h` press data and `AX=0006h` release data. `python3 scripts/test_mousecb.py` failed before the release-query fix with `FAIL: MOUSECB RELEASEDATA` and passes after it.
- `make test` passes `73/73`, and `make test-game-smokes` still passes the current game smoke ladder after the mouse-release fix.
- User manual retest confirmed the Stunt competition prompt mouse clicks now work with the current kernel.
