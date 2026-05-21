[bits 16]
[org 0x0100]

    mov ah, 0x09
    mov dx, msg
    int 0x21
    mov ah, 0x4C
    mov al, 0x00
    int 0x21

msg: db "PASS: HELLO.COM", 13, 10, "$"
