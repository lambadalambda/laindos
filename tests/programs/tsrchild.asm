[bits 16]
[org 0x0100]

start:
    mov dx, 0x0030
    mov ax, 0x3142
    int 0x21
    push cs
    pop ds
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fail_msg: db "FAIL: TSRCHILD RETURNED", 13, 10, "$"
