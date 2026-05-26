---
name: qemu-protected-mode-triage
description: DOS4GW fprem fsin fcos x87 info registers x /Ni $eip xp /1dw 0x46c -cpu -vga real DOS in QEMU. Use when a DOS extender or protected-mode game stalls in QEMU after startup and you need short discriminator probes before changing LainDOS.
---

# QEMU Protected-Mode Triage

Use this skill when a DOS extender or protected-mode game appears stuck in QEMU and the DOS file/API trace is no longer enough.

## Fast Discriminators

1. Reproduce under real DOS in QEMU if possible.
2. Sample CPU state with the monitor instead of waiting longer.
3. Try short `-cpu` / `-vga` sweeps only if they are cheap.

## Monitor Commands

Use these during the stall:

```text
info registers
x /12i $eip
xp /1dw 0x46c
```

Interpretation:

- `0x46c` advancing means BIOS timer is still alive.
- x87 loops like `fprem`, `fcos`, `fsin` point away from DOS file I/O and toward QEMU CPU/FPU behavior.
- Repeated `AH=42h AL=01h OFF=0` in DOS trace means tell-style polling, not necessarily the root cause.

## Heuristics

- If real DOS in QEMU also stalls, stop treating it as a LainDOS DOS/filesystem bug.
- If 86Box softfloat still progresses while QEMU stalls, suspect QEMU-specific FPU helper behavior.
- If `fninit` before exec does not change the stall, dirty initial x87 state is less likely than a deeper QEMU x87 issue.

## Useful Short Experiments

- CPU sweep: `-cpu 486`, `-cpu pentium2`, `-cpu pentium,-fpu`, `-cpu qemu64`
- VGA sweep: default, `-vga cirrus`
- Real DOS + `file=fat:rw:<hostdir>`

These experiments are meant to classify quickly, not to solve the bug by themselves.

## Current Repo Lessons

As of the current investigation:

- Ascendancy’s remaining QEMU-only stall reproduced under real DOS in QEMU.
- CPU snapshots showed DOS/4GW x87 helpers, not DOS calls, at the active stall point.
- 86Box with S3 Trio PCI progressed; even 86Box softfloat plus dynarec-off still progressed.

## References

- `docs/emulator_workflows.md`
- `docs/debug_log.md`
