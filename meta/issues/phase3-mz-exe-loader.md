# Phase 3: MZ .EXE Loader

## Summary

Implement the MZ .EXE loader with header parsing, relocation, PSP creation, and proper CS:IP/SS:SP setup. This is the central loader for running Monkey Island.

## Requirements

- Parse MZ header (signature, image size, relocation count, SS:SP, CS:IP)
- Compute image size from header fields
- Allocate memory block for PSP + program image + minimum extra memory
- Build PSP at the load segment
- Load executable image at PSP + 10h
- Apply relocation table by adding the load segment
- Set up initial CS:IP and SS:SP from header
- Set DS = ES = PSP segment
- Far jump to program entry point

## Acceptance Criteria

- HELLO.EXE (simple MZ executable) runs in QEMU
- Relocation entries are correctly applied
- PSP, stack, CS:IP, and SS:SP are set up per MZ header values
- Program termination returns control to kernel
