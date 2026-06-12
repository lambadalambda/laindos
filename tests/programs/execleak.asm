[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov ah, 0x3C
    xor cx, cx
    mov dx, datname
    int 0x21
    jc fail_setup
    mov [handle], ax

    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, exename
    mov ax, 0x4B00
    int 0x21
    jnc fail_exec_ok
    cmp ax, 11
    jne fail_exec_code

    mov bx, exec_params
    mov dx, exename
    mov ax, 0x4B00
    int 0x21
    jnc fail_exec_ok
    mov dx, msg_exec
    mov ah, 0x09
    int 0x21

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov ah, 0x3C
    xor cx, cx
    mov dx, datname
    int 0x21
    jc fail_recreate
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    mov dx, msg_leak
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_exec_ok:
    mov dx, msg_fail_exec_ok
    jmp fail
fail_exec_code:
    mov dx, msg_fail_exec_code
    jmp fail
fail_close:
    mov dx, msg_fail_close
    jmp fail
fail_recreate:
    mov dx, msg_fail_leak
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
datname: db "LEAK.DAT", 0
exename: db "BADREL.EXE", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
msg_exec:           db "PASS: EXECLEAK EXEC", 13, 10, '$'
msg_leak:           db "PASS: EXECLEAK NOLEAK", 13, 10, '$'
msg_fail_setup:     db "FAIL: EXECLEAK SETUP", 13, 10, '$'
msg_fail_exec_ok:   db "FAIL: EXECLEAK EXEC OK", 13, 10, '$'
msg_fail_exec_code: db "FAIL: EXECLEAK EXEC CODE", 13, 10, '$'
msg_fail_close:     db "FAIL: EXECLEAK CLOSE", 13, 10, '$'
msg_fail_leak:      db "FAIL: EXECLEAK LEAK", 13, 10, '$'
