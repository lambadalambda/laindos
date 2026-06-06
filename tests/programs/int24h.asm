[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, ok_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

ok_msg: db 'PASS: INT24H', 13, 10, '$'
