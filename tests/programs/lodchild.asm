[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dx, msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

msg: db "PASS: EXECLOAD RUN", 13, 10, '$'
