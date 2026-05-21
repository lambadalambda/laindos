# Phase 5: DOS Memory Allocator

## Summary

Implement the DOS Memory Control Block (MCB) chain and the INT 21h memory allocation functions: allocate, free, and resize.

## Requirements

- MCB chain with classic structure: signature ('M' or 'Z'), owner PSP, size in paragraphs
- INT 21h AH=48h allocate memory block (first fit or best fit)
- INT 21h AH=49h free memory block
- INT 21h AH=4Ah resize memory block
- Merge adjacent free blocks on free/resize
- Return DOS-like error codes with carry flag set on failure
- INT 21h AH=58h get/set allocation strategy (optional, can stub)

## Acceptance Criteria

- Test EXE allocates, resizes, and frees memory via INT 21h
- MCB chain survives multiple alloc/free cycles without corruption
- Largest-free-block reporting is plausible
- Adjacent free blocks are merged
- Error codes returned with carry flag on failure
