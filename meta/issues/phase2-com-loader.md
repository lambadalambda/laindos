# Phase 2: .COM Loader

## Summary

Implement a .COM program loader so LainDOS can run simple flat-model 16-bit .COM executables, and INT 20h / INT 21h AH=4Ch termination.

## Requirements

- Load .COM file at PSP:0100h
- Build a minimal PSP (at least INT 20h at offset 00h, end segment at 02h)
- Set up CS=DS=ES=SS=PSP segment, SP at top of segment
- INT 20h terminates the running program
- INT 21h AH=4Ch terminates with return code
- Execution returns to kernel after program termination

## Acceptance Criteria

- HELLO.COM runs in QEMU and prints output
- Program termination via INT 20h or INT 21h AH=4Ch returns control to kernel
- PSP is correctly set up at the load segment
