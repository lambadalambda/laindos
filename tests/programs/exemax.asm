%include "tests/programs/common.inc"

MZ_HEADER

image_start:
    mov ax, ds
    mov bx, [0x02]
    sub bx, ax
    cmp bx, 0x1000
    jae pass

fail:
    push cs
    pop ds
    mov ah, 0x09
    mov dx, fail_msg - image_start
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass:
    push cs
    pop ds
    mov ah, 0x09
    mov dx, pass_msg - image_start
    int 0x21
    mov ax, 0x4C00
    int 0x21

pass_msg: db "PASS: EXEMAX", 13, 10, "$"
fail_msg: db "FAIL: EXEMAX", 13, 10, "$"

file_end:
