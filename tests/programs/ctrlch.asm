[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    mov ax, 0x2523
    mov dx, handler
    int 0x21
    mov dx, ready_msg
    mov ah, 0x09
    int 0x21
.loop:
    cmp byte [seen], 1
    je .done
    mov ah, 0x01
    int 0x21
    jmp .loop
.done:
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

handler:
    mov byte [cs:seen], 1
    iret

seen: db 0
ready_msg: db "READY: CTRLCH", 13, 10, '$'
pass_msg:  db "PASS: CTRLCH", 13, 10, '$'
