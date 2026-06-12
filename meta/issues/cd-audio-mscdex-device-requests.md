# CD audio: MSCDEX device requests (INT 2Fh AX=1510h)

## Summary

Settlers II Gold reports "no audio tracks" even under 86Box with the full
mixed-mode cue/bin mounted. The cause is on our side: the kernel's MSCDEX
surface implements only AX=1500h/150Bh/150Ch/150Dh. Games do CD audio
through AX=1510h ("send device driver request"): they read the TOC via
IOCTL Input control blocks 10/11 (Audio Disc Info / Audio Track Info) and
control playback via device commands 132/133/136 (Play/Stop/Resume
Audio). None of that path exists, so no game can even enumerate audio
tracks.

## Requirements

- INT 2Fh AX=1510h dispatcher: parse the DOS device request header at
  ES:BX, validate the drive (CX), set the status word (done/error bits,
  error codes) like a real CD-ROM device driver.
- IOCTL Input control blocks needed for audio: 10 (Audio Disc Info),
  11 (Audio Track Info), plus the cheap ones games probe (6 device
  status, 9 media changed, 7 sector size, 8 volume size).
- Device commands 132 (Play Audio, HSG and Red Book addressing),
  133 (Stop), 136 (Resume).
- ATAPI backend: READ TOC (0x43), PLAY AUDIO MSF (0x47), STOP PLAY/SCAN
  (0x4E), PAUSE/RESUME (0x4B). The PIO packet plumbing already exists for
  READ(10); generalize it for variable-length responses and zero-length
  command packets.
- Lazy ATAPI detection: under QEMU the EDD probe wins the mount and
  `atapi_base` stays 0; audio requests must trigger the ATAPI scan on
  first use so both read methods can serve audio commands.

## Acceptance Criteria

- A small test program (tests/programs/cdaudio.asm, per the cdmscdex.asm
  pattern) exercises 1510h against the generated single-data-track ISO
  under QEMU: bogus command -> done+error 3; Audio Disc Info -> tracks
  1..1 with a nonzero lead-out; Audio Track Info(1) -> data-track control
  bit; Play on the data disc returns (done set) without wedging; Stop
  returns done without error. Registered in the default ladder.
- Settlers II under 86Box with the cue/bin loaded sees its eight audio
  tracks (user-verifiable in the VM; a vendor-gated 86Box TOC check is a
  stretch goal).
- Docs updated in lockstep.

## Resolution (2026-06-12)

- Implemented the INT 2Fh AX=1510h dispatcher with the audio IOCTL
  control blocks (6/7/8/9/10/11/12/15) and Play/Stop/Resume commands
  over a generalized ATAPI packet path, with lazy transport bring-up
  (IDENTIFY PACKET DEVICE fallback when the BIOS has consumed the
  power-on signature) and a division-overflow guard on hostile play
  addresses. `test_cd_audio` pins the contract in the default ladder;
  suite 143/143.
- The first 86Box run exposed the spec's busy bit: CD player UIs poll
  status-word bit 9 (0x0200) to track playback, and Stop Audio (133)
  carries pause-with-resume-point semantics. Both fixed.
- User-confirmed under 86Box with the mixed-mode cue/bin: Settlers II
  lists all eight audio tracks, selection plays, stop stops —
  "THERE WE GO, all fixed!"

## Notes

- The smoke's `build/settlers2_cd.iso` is data-track-only; actual audio
  playback needs the cue/bin under 86Box. QEMU's ATAPI still answers
  READ TOC for a plain ISO (one data track), which is what makes the
  default-ladder test possible.
- MSCDEX track control byte convention: ATAPI's ADR/control low nibble
  shifted into the high nibble (data track = 0x40).
