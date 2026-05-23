[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    mov ah, 0x62
    int 0x21
    mov [cmd_tail+1], bx
    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail
    mov ah, 0x4D
    int 0x21
    test al, al
    jnz fail
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

child_path: db "PSPCHILD.COM", 0
cmd_tail: db 2, 0, 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
pass_msg: db "PASS: PSP", 13, 10, "$"
fail_msg: db "FAIL: PSP", 13, 10, "$"
