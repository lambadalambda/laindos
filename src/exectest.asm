[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, hello_path
    mov ax, 0x4B00
    int 0x21
    jc fail
    mov ah, 0x4D
    int 0x21
    cmp al, 0
    jne fail
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail:
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

hello_path: db "HELLO.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
pass_msg: db "PASS: EXECTEST", 13, 10, "$"
fail_msg: db "FAIL: EXECTEST", 13, 10, "$"
