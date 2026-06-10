# Unify boot-time and EXEC loader sizing logic

## Summary

The boot-time COM/EXE sizing and allocation logic (`src/kernel.asm:242-341`) duplicates `load_exec_program` (`src/kernel/exec.inc:53-226`) nearly line-for-line and has already diverged: exec.inc has `adc dx,0` plus a dx-overflow check after its shl-5 (exec.inc:101-109) that the kernel.asm `.shl5m` path (291-301) lacks, and the boot copy misses the `test dx,dx / jnz .exe_too_large` guards. The header-pages-to-bytes computation exists in three copies (exec.inc:58-74, 752-767, kernel.asm:268-296), the bytes-to-paragraphs rounding in three (exec.inc:92-107, 150-165, kernel.asm:247-264), and the reloc-table bounds validation in two with diverging strictness (exec.inc:776-789 vs 1482-1501).

## Requirements

- Extract shared sizing/validation subroutines used by both the boot loader and `load_exec_program` (and the overlay path), keeping the strictest variant of each guard.

## Acceptance Criteria

- Pure refactor: full test ladder passes, including boot, exec, overlay, exemax, and badreloc tests; the duplicated sequences are gone (single definition each).

## Notes

- Overlaps with [Guard EXE header math against 16-bit overflow](guard-exe-header-math-overflows.md) — landing that first makes the strictest-variant choice obvious.
