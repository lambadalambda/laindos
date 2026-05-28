[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    mov [exec_params+4], ds

    mov dx, badexe_name
    mov bx, exec_params
    mov ax, 0x4B00
    int 0x21
    jnc .fail_exec

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_exec:
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

badexe_name: db "BADRELOC.EXE", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
pass_msg: db "PASS: BADRELOC", 13, 10, "$"
fail_msg: db "FAIL: BADRELOC EXEC", 13, 10, "$"
