[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

pass_msg: db "PASS: PATHRUN", 13, 10, "$"
