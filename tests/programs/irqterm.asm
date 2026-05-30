[bits 16]
[org 0x0100]

start:
    xor ax, ax
    mov ds, ax
    xor dx, dx
    mov ax, 0x2509
    int 0x21
    mov ax, 0x4C00
    int 0x21
