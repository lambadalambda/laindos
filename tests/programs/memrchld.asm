[bits 16]
[org 0x0100]

start:
    mov bx, 0x0100
    mov ah, 0x48
    int 0x21
    jc fail
    mov [block1], ax

    mov bx, 0x0080
    mov ah, 0x48
    int 0x21
    jc fail
    mov [block2], ax

    mov ax, 0x4C00
    int 0x21

fail:
    mov ax, 0x4C02
    int 0x21

block1: dw 0
block2: dw 0
