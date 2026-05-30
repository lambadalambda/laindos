[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x3509
    int 0x21
    mov [old_int9_off], bx
    mov [old_int9_seg], es

    in al, 0x21
    mov [initial_pic], al
    test al, 0x02
    jnz fail_initial

    push ds
    xor ax, ax
    mov ds, ax
    xor dx, dx
    mov ax, 0x2509
    int 0x21
    pop ds

    in al, 0x21
    test al, 0x02
    jz fail_mask

    push ds
    mov dx, [old_int9_off]
    mov ax, [old_int9_seg]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    pop ds

    in al, 0x21
    xor al, [initial_pic]
    test al, 0x02
    jnz fail_restore

    mov [exec_params+4], ds
    push ds
    pop es
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec

    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_child

    in al, 0x21
    xor al, [initial_pic]
    test al, 0x02
    jnz fail_term_restore

    push ds
    mov dx, [old_int9_off]
    mov ax, [old_int9_seg]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    pop ds

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_initial:
    mov dx, fail_initial_msg
    jmp fail
fail_mask:
    mov dx, fail_mask_msg
    jmp fail
fail_restore:
    mov dx, fail_restore_msg
    jmp fail
fail_exec:
    mov dx, fail_exec_msg
    jmp fail
fail_child:
    mov dx, fail_child_msg
    jmp fail
fail_term_restore:
    mov dx, fail_term_restore_msg
fail:
    mov ah, 0x09
    int 0x21
    push ds
    mov dx, [old_int9_off]
    mov ax, [old_int9_seg]
    mov ds, ax
    mov ax, 0x2509
    int 0x21
    pop ds
    mov ax, 0x4C01
    int 0x21

old_int9_off: dw 0
old_int9_seg: dw 0
initial_pic: db 0
child_path: db "IRQTERM.COM", 0
empty_tail: db 0, 13
exec_params:
    dw 0
    dw empty_tail, 0
    dw 0, 0
    dw 0, 0
pass_msg: db "PASS: IRQMASK", 13, 10, "$"
fail_initial_msg: db "FAIL: IRQMASK INITIAL", 13, 10, "$"
fail_mask_msg: db "FAIL: IRQMASK MASK", 13, 10, "$"
fail_restore_msg: db "FAIL: IRQMASK RESTORE", 13, 10, "$"
fail_exec_msg: db "FAIL: IRQMASK EXEC", 13, 10, "$"
fail_child_msg: db "FAIL: IRQMASK CHILD", 13, 10, "$"
fail_term_restore_msg: db "FAIL: IRQMASK TERMRESTORE", 13, 10, "$"
