[bits 16]
[org 0x0100]

start:
    test ax, ax
    jnz fail
    push cs
    pop ds
    mov dx, msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21
fail:
    push cs
    pop ds
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

msg:      db "PASS: EXECLOAD AX", 13, 10, '$'
fail_msg: db "FAIL: EXECLOAD AX", 13, 10, '$'
