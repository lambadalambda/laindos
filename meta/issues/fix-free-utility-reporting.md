# Fix FREE utility reporting

## Summary

Three bugs in `programs/free.asm`. (a) XMS function 08h returns AX=largest free block and DX=total free KB; the code stores DX into both `xms_total_kb` and `xms_free_kb` (free.asm:86-89, 118-120), so the Total column shows current free and the computed used column is structurally always 0K. (b) `print_dword_dec`'s power table tops out at 10^7 (free.asm:434-443); `print_ems_amount` feeds it values up to 2^30, and anything >= 10^8 emits garbage digit characters (shell.asm's `dir_pow10_table` correctly goes to 10^9). (c) `collect_mcb`'s corruption defenses (free.asm:59-66) miss `size = 0xFFFF`, where `next = si + 1 + 0xFFFF` wraps back to `si` and the walk loops forever on a valid signature.

## Requirements

- Report installed XMS total (e.g. via INT 15h AH=88h or by summing blocks) or relabel the column; keep free from DX.
- Extend the decimal power table to 10^9.
- Detect non-advancing MCB walks and bail to `bad_chain`.

## Acceptance Criteria

- FREE output shows distinct, plausible total/free/used XMS under QEMU; values >= 10^8 print correctly (unit-style check via a crafted EMS page count or direct call); `PASS:` markers in a small test script.
