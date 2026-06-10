# Keep the TSR environment block resident

## Summary

On AH=31h, `tsr_free_owned_extra` (`src/kernel.asm:2345-2369`) frees every block owned by `cur_psp` except the PSP block itself — including the environment block, whose MCB owner was set to the child PSP by `assign_exec_environment_owner` (`src/kernel/exec.inc:683-703`) and whose segment is stored at PSP:2Ch (exec.inc:1389-1390). The resident program's PSP:2Ch then points at a free block that the next allocation overwrites. Real DOS keeps the TSR's environment resident.

## Requirements

- Exclude the block referenced by the terminating PSP's offset 2Ch from `tsr_free_owned_extra`.

## Acceptance Criteria

- Test: TSR child stores a marker string in its environment, terminates resident; parent allocates/uses memory, then reads the TSR's PSP:2Ch environment and verifies the marker is intact; `PASS:` markers.
- Existing TSR tests pass.
