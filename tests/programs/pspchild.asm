[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov ax, [0x16]
    cmp ax, [0x81]
    jne fail
    mov dx, ax
    mov ah, 0x62
    int 0x21
    cmp bx, dx
    je fail
    test dx, dx
    jz fail
    mov ax, 0x4C00
    int 0x21

fail:
    mov ax, 0x4C01
    int 0x21
