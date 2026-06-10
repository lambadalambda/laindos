[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, child1
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    mov dx, msg_kill
    mov ah, 0x09
    int 0x21

    mov bx, exec_params
    mov dx, child2
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_cont
    mov dx, msg_cont
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_exec:
    mov dx, msg_fail_exec
    jmp fail
fail_cont:
    mov dx, msg_fail_cont
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

child1: db "CTRLCC.COM", 0
child2: db "CTRLCH.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
msg_kill:      db "PASS: CTRLC KILL", 13, 10, '$'
msg_cont:      db "PASS: CTRLC CONT", 13, 10, '$'
msg_fail_exec: db "FAIL: CTRLC EXEC", 13, 10, '$'
msg_fail_cont: db "FAIL: CTRLC CONT", 13, 10, '$'
