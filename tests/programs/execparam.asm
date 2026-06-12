[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    push cs
    pop es

    mov [exec_params+4], ds
    mov [exec_params+8], ds
    mov [exec_params+12], ds

    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B7F
    int 0x21
    jnc fail_badfunc
    cmp ax, 1
    jne fail_badfunc

    mov bx, exec_params
    mov dx, missing_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_missing
    cmp ax, 2
    jne fail_missing

    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec_full
    mov ah, 0x4D
    int 0x21
    cmp ax, 0x0025
    jne fail_return_full

    push cs
    pop ds
    xor ax, ax
    mov es, ax
    xor bx, bx
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec_null
    mov ah, 0x4D
    int 0x21
    cmp ax, 0x0025
    jne fail_return_null

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_badfunc:
    push cs
    pop ds
    mov dx, fail_badfunc_msg
    jmp fail
fail_missing:
    push cs
    pop ds
    mov dx, fail_missing_msg
    jmp fail
fail_exec_full:
    push cs
    pop ds
    mov dx, fail_exec_full_msg
    jmp fail
fail_return_full:
    push cs
    pop ds
    mov dx, fail_return_full_msg
    jmp fail
fail_exec_null:
    push cs
    pop ds
    mov dx, fail_exec_null_msg
    jmp fail
fail_return_null:
    push cs
    pop ds
    mov dx, fail_return_null_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

child_path: db "EXECPCHK.COM", 0
missing_path: db "NOEXEC.COM", 0
cmd_tail: db 8, " /EDGE42", 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw fcb1, 0
    dw fcb2, 0
fcb1: db 1, "FIRST   TXT", 0x11, 0x22, 0x33, 0x44
fcb2: db 2, "SECOND  BIN", 0x55, 0x66, 0x77, 0x88
pass_msg: db "PASS: EXECPARAM", 13, 10, "$"
fail_badfunc_msg: db "FAIL: EXECPARAM BADFUNC", 13, 10, "$"
fail_missing_msg: db "FAIL: EXECPARAM MISSING", 13, 10, "$"
fail_exec_full_msg: db "FAIL: EXECPARAM EXEC FULL", 13, 10, "$"
fail_return_full_msg: db "FAIL: EXECPARAM RETURN FULL", 13, 10, "$"
fail_exec_null_msg: db "FAIL: EXECPARAM EXEC NULL", 13, 10, "$"
fail_return_null_msg: db "FAIL: EXECPARAM RETURN NULL", 13, 10, "$"
