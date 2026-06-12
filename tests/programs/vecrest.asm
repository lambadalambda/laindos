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

    mov ax, 0x3522
    int 0x21
    mov [old22], bx
    mov [old22+2], es
    push cs
    pop es
    mov ax, 0x3523
    int 0x21
    mov [old23], bx
    mov [old23+2], es
    push cs
    pop es
    mov ax, 0x3524
    int 0x21
    mov [old24], bx
    mov [old24+2], es
    push cs
    pop es

    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_child

    mov ax, 0x3523
    int 0x21
    cmp bx, [old23]
    jne fail_vec23
    mov ax, es
    cmp ax, [old23+2]
    jne fail_vec23
    push cs
    pop es
    mov ax, 0x3524
    int 0x21
    cmp bx, [old24]
    jne fail_vec24
    mov ax, es
    cmp ax, [old24+2]
    jne fail_vec24
    push cs
    pop es
    mov ax, 0x3522
    int 0x21
    cmp bx, [old22]
    jne fail_vec22
    mov ax, es
    cmp ax, [old22+2]
    jne fail_vec22
    push cs
    pop es

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_exec:
    push cs
    pop ds
    mov dx, fail_exec_msg
    jmp fail
fail_child:
    mov dx, fail_child_msg
    jmp fail
fail_vec22:
    push cs
    pop ds
    mov dx, fail_vec22_msg
    jmp fail
fail_vec23:
    push cs
    pop ds
    mov dx, fail_vec23_msg
    jmp fail
fail_vec24:
    push cs
    pop ds
    mov dx, fail_vec24_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

old22: dw 0, 0
old23: dw 0, 0
old24: dw 0, 0
child_path: db "VECCHILD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
pass_msg:      db "PASS: VECREST", 13, 10, '$'
fail_exec_msg: db "FAIL: VECREST EXEC", 13, 10, '$'
fail_child_msg: db "FAIL: VECREST CHILD", 13, 10, '$'
fail_vec22_msg: db "FAIL: VECREST 22", 13, 10, '$'
fail_vec23_msg: db "FAIL: VECREST 23", 13, 10, '$'
fail_vec24_msg: db "FAIL: VECREST 24", 13, 10, '$'
