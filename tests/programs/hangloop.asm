[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dx, msg
    mov ah, 0x09
    int 0x21
.hang:
    jmp .hang

msg: db "PASS: HANGLOOP", 13, 10, "$"
