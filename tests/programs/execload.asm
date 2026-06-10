[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, ax_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_exec

    push cs
    pop es
    mov bx, exec_params
    mov dx, lod_path
    mov ax, 0x4B01
    int 0x21
    jc fail_load
    mov ax, [exec_params+0x12]
    cmp ax, 0x0100
    jne fail_block
    mov ax, [exec_params+0x14]
    test ax, ax
    jz fail_block
    mov ax, [exec_params+0x0E]
    cmp ax, 0x0200
    jb fail_block
    push cs
    pop ds
    mov dx, msg_block
    mov ah, 0x09
    int 0x21

    cli
    mov ss, [exec_params+0x10]
    mov sp, [exec_params+0x0E]
    sti
    push word [cs:exec_params+0x14]
    push word [cs:exec_params+0x12]
    retf

fail_exec:
    push cs
    pop ds
    mov dx, msg_fail_exec
    jmp fail
fail_load:
    mov dx, msg_fail_load
    jmp fail
fail_block:
    mov dx, msg_fail_block
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

ax_path:  db "AXCHILD.COM", 0
lod_path: db "LODCHILD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0, 0, 0, 0, 0
msg_block:     db "PASS: EXECLOAD BLOCK", 13, 10, '$'
msg_fail_exec: db "FAIL: EXECLOAD EXEC", 13, 10, '$'
msg_fail_load: db "FAIL: EXECLOAD LOAD", 13, 10, '$'
msg_fail_block: db "FAIL: EXECLOAD BLOCK", 13, 10, '$'
