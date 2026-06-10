[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x2523
    mov dx, stub23
    int 0x21
    mov ax, 0x2524
    mov dx, stub24
    int 0x21

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

stub23:
    iret
stub24:
    mov al, 1
    iret

pass_msg: db "PASS: VECCHILD", 13, 10, '$'
