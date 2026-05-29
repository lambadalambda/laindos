[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    mov ah, 0x62
    int 0x21
    mov [psp_seg], bx

    mov bx, 0x0010
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [env_seg], ax
    mov [exec_params], ax
    mov es, ax
    xor di, di
    mov si, custom_var
.copy_var:
    lodsb
    stosb
    test al, al
    jnz .copy_var
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
    jc fail_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_child

    mov ax, [env_seg]
    dec ax
    mov ds, ax
    mov ax, [cs:psp_seg]
    cmp [1], ax
    jne fail_owner

    push cs
    pop ds
    mov es, [env_seg]
    mov ah, 0x49
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
fail_exec:
    mov dx, fail_exec_msg
    jmp fail
fail_child:
    mov dx, fail_child_msg
    jmp fail
fail_owner:
    push cs
    pop ds
    mov dx, fail_owner_msg
    jmp fail
fail_free:
    mov dx, fail_free_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

psp_seg: dw 0
env_seg: dw 0
child_path: db "ENVCHILD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0
custom_var: db "CUSTOM=YES", 0
pass_msg: db "PASS: EXECENV", 13, 10, "$"
fail_alloc_msg: db "FAIL: EXECENV ALLOC", 13, 10, "$"
fail_exec_msg: db "FAIL: EXECENV EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: EXECENV CHILD", 13, 10, "$"
fail_owner_msg: db "FAIL: EXECENV OWNER", 13, 10, "$"
fail_free_msg: db "FAIL: EXECENV FREE", 13, 10, "$"
