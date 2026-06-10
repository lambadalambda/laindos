[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov dx, ready_msg
    mov ah, 0x09
    int 0x21
.loop:
    mov ah, 0x01
    int 0x21
    jmp .loop

ready_msg: db "READY: CTRLCC", 13, 10, '$'
