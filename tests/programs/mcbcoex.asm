[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es

    mov word [run_idx], 0

.run_loop:
    call query_largest
    mov [initial_largest], bx

    mov bx, 0x0012
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [test_alloc], ax
    mov [exec_params], ax
    mov [exec_params+4], ds

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
    call query_largest
    mov [largest_after_alloc], bx

    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jnc fail_unexpected
    cmp ax, 8
    jne fail_wrong_code

    call query_largest
    mov [largest_after_exec], bx

    mov ax, [largest_after_alloc]
    cmp bx, ax
    jne fail_largest

    mov ah, 0x49
    mov es, [test_alloc]
    int 0x21
    jc fail_free

    inc word [run_idx]
    cmp word [run_idx], 5
    jb .run_loop

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

query_largest:
    mov bx, 0xFFFF
    mov ah, 0x48
    int 0x21
    jnc fail_largest
    cmp ax, 8
    jne fail_largest
    ret

fail_alloc:
    push cs
    pop ds
    mov dx, fail_alloc_msg
    jmp fail
fail_largest:
    push cs
    pop ds
    mov dx, fail_largest_msg
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

run_idx: dw 0
initial_largest: dw 0
largest_after_alloc: dw 0
largest_after_exec: dw 0
test_alloc: dw 0
child_path: db "ENVCHILD.COM", 0
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

pass_msg: db "PASS: MCBCOEX", 13, 10, "$"
fail_alloc_msg: db "FAIL: MCBCOEX ALLOC", 13, 10, "$"
fail_largest_msg: db "FAIL: MCBCOEX LARGEST", 13, 10, "$"
fail_unexpected_msg: db "FAIL: MCBCOEX UNEXPECTED", 13, 10, "$"
fail_wrong_code_msg: db "FAIL: MCBCOEX CODE", 13, 10, "$"
fail_free_msg: db "FAIL: MCBCOEX FREE", 13, 10, "$"
