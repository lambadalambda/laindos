# Move the kernel to the High Memory Area

## Summary

The resident kernel currently occupies most of the low 64 KiB: image at phys 0x02000-0x0AD21 (36,129 bytes, ~735 bytes of growth headroom before it hits SEC_BUF at 0x0B000), sector/read-cache buffers at 0x0B000-0x0B400, root buffer at 0x0B400-0x0F400, stack to 0x0FC00, MCB arena from segment 0x1000 to MEM_TOP 0xA000 = 576 KiB user RAM. Every kernel feature added now either hits the build assert or costs user conventional memory. Moving the kernel image and stack to the HMA (0xFFFF:0010, ~64 KiB-16) frees the 0x0200-0x0B00 region, lets the low buffers pack downward, and drops MCB_START to ~0x0700 for ~612 KiB free conventional RAM plus ~20 KiB of code growth headroom.

The kernel is well-positioned for this: it is a single cs-relative segment already relocated at boot (LOAD_SEG 0x1000 down to RELOC_SEG 0x0200), and LainDOS is itself the XMS/A20 provider, so nothing else in the system has standing to disable A20.

## Requirements

- Enable and verify the A20 line during early kernel init (port 0x92 fast A20, verified by a wraparound write test); halt with a clear serial/VGA error if A20 cannot be enabled.
- Relocate the kernel image to 0xFFFF:0010 (org 0x10) and run with CS=SS=0xFFFF; interrupt vectors point directly into the HMA.
- Keep all disk-target buffers (FAT, CD, sector, read cache, root) in low memory; no INT 13h transfer may target the HMA.
- Pack the low buffers into the freed region and lower MCB_START accordingly; MEM_TOP and the EMS frame layout are unchanged.
- XMS A20 functions (03h-07h) must report A20 enabled and never actually disable it; document this divergence.
- Update the build-time layout asserts for the new map, and update README/docs/site memory-layout material in lockstep.

## Acceptance Criteria

- New test program verifies: INT 21h vector segment is 0xFFFF (AH=35h), A20 is on (wraparound test), and the largest free block (AH=48h BX=0xFFFF) is at least 0x9700 paragraphs (~605 KiB).
- Full test ladder passes, including Monkey Island, Sam & Max, and EMS/XMS tests.
- Boot still works under both QEMU and Bochs.

## Notes

- Real-hardware caveat (acceptable for the emulator-first target): a program that disables A20 behind the kernel's back would unmap the interrupt handlers. A low-memory entry stub is the robust pattern if real hardware ever becomes a target; out of scope here.
- The pre-relocation entry code runs at LOAD_SEG before the move; with org 0x10 the boot loader must transfer to (LOAD_SEG-1):0x0010 so offsets match.
- Filed from the 2026-06-10 memory-pressure discussion; see also [Bound volume buffers against BPB geometry](bound-volume-buffers-against-bpb-geometry.md) which touches the same low-memory map.
