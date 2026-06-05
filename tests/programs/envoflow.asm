[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    mov bx, 0x0012
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [env_seg], ax
    mov [exec_params], ax

    mov es, ax
    xor di, di
    mov si, big_var
    mov cx, big_var_end - big_var
    rep movsb
    xor ax, ax
    stosb
    stosw

    push cs
    pop ds
    push cs
    pop es
    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_unexpected
    cmp ax, 8
    jne fail_wrong_code

    push cs
    pop es
    mov bx, 0x0008
    mov ah, 0x48
    int 0x21
    jc fail_mcb_corrupt
    mov es, ax

    mov ah, 0x49
    int 0x21
    jc fail_free

    push cs
    pop es
    mov ah, 0x49
    mov es, [env_seg]
    int 0x21
    jc fail_free

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_alloc:
    push cs
    pop ds
    mov dx, fail_alloc_msg
    jmp fail
fail_mcb_corrupt:
    push cs
    pop ds
    mov dx, fail_mcb_msg
    jmp fail
fail_unexpected:
    push cs
    pop ds
    mov dx, fail_unexpected_msg
    jmp fail
fail_wrong_code:
    push cs
    pop ds
    mov dx, fail_wrong_code_msg
    jmp fail
fail_free:
    push cs
    pop ds
    mov dx, fail_free_msg
    jmp fail
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

env_seg: dw 0
child_path: db ".\ENVCHILD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0

big_var: db "BIG="
times 260 db 'A'
db 0
big_var_end:

pass_msg: db "PASS: EXECENV_OVERFLOW", 13, 10, "$"
fail_alloc_msg: db "FAIL: EXECENV_OVERFLOW ALLOC", 13, 10, "$"
fail_mcb_msg: db "FAIL: EXECENV_OVERFLOW MCB", 13, 10, "$"
fail_unexpected_msg: db "FAIL: EXECENV_OVERFLOW UNEXPECTED", 13, 10, "$"
fail_wrong_code_msg: db "FAIL: EXECENV_OVERFLOW CODE", 13, 10, "$"
fail_free_msg: db "FAIL: EXECENV_OVERFLOW FREE", 13, 10, "$"
