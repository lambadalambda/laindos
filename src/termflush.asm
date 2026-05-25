[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, file_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, payload
    mov cx, payload_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, payload_size
    jne fail_write

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
file_name: db "TERMOUT.DAT", 0
payload: db "termination flush payload", 13, 10
payload_size equ $ - payload
pass_msg: db "PASS: TERMFLUSH", 13, 10, "$"
fail_create_msg: db "FAIL: TERMFLUSH CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: TERMFLUSH WRITE", 13, 10, "$"
