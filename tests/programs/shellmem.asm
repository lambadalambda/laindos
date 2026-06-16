%include "tests/programs/common.inc"

MIN_CHILD_PARAS equ 580 * 64

COM_START
    mov ax, [cs:0x02]
    mov bx, cs
    sub ax, bx
    cmp ax, MIN_CHILD_PARAS
    jb fail
    PASS_WITH pass_msg

fail:
    FAIL_WITH fail_msg

pass_msg: db "PASS: SHELLMEM", 13, 10, "$"
fail_msg: db "FAIL: SHELLMEM", 13, 10, "$"
