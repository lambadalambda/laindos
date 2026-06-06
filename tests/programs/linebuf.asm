[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    mov byte [buf0], 0
    mov byte [buf0+1], 0xCC
    mov byte [buf0+2], 0xCC
    mov byte [buf0+3], 0xCC
    mov dx, buf0
    mov ah, 0x0A
    int 0x21
    cmp byte [buf0+1], 0
    jne fail_max0_count
    cmp byte [buf0+2], 0xCC
    jne fail_max0_cr
    cmp byte [buf0+3], 0xCC
    jne fail_max0_cr2

    mov byte [buf2], 3
    mov byte [buf2+1], 0xCC
    mov byte [buf2+2], 0xCC
    mov byte [buf2+3], 0xCC
    mov byte [buf2+4], 0xCC
    mov dx, ready_msg
    mov ah, 0x09
    int 0x21
    mov dx, buf2
    mov ah, 0x0A
    int 0x21
    cmp byte [buf2+1], 2
    jne fail_max2_count
    cmp byte [buf2+2], 'x'
    jne fail_max2_x
    cmp byte [buf2+3], 'z'
    jne fail_max2_z
    cmp byte [buf2+4], 13
    jne fail_max2_cr

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_max0_count:
    mov dx, fail_max0_count_msg
    jmp fail
fail_max0_cr:
    mov dx, fail_max0_cr_msg
    jmp fail
fail_max0_cr2:
    mov dx, fail_max0_cr2_msg
    jmp fail
fail_max2_count:
    mov dx, fail_max2_count_msg
    jmp fail
fail_max2_x:
    mov dx, fail_max2_x_msg
    jmp fail
fail_max2_z:
    mov dx, fail_max2_z_msg
    jmp fail
fail_max2_cr:
    mov dx, fail_max2_cr_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

buf0: times 4 db 0
buf2: times 5 db 0
ready_msg: db "READY: LINEBUF", 13, 10, "$"
pass_msg: db "PASS: LINEBUF", 13, 10, "$"
fail_max0_count_msg: db "FAIL: LINEBUF MAX0 COUNT$"
fail_max0_cr_msg: db "FAIL: LINEBUF MAX0 CR$"
fail_max0_cr2_msg: db "FAIL: LINEBUF MAX0 CR2$"
fail_max2_count_msg: db "FAIL: LINEBUF MAX2 COUNT$"
fail_max2_x_msg: db "FAIL: LINEBUF MAX2 X$"
fail_max2_z_msg: db "FAIL: LINEBUF MAX2 Z$"
fail_max2_cr_msg: db "FAIL: LINEBUF MAX2 CR$"
