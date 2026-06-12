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

    mov ah, 0x48
    mov bx, 0x60
    int 0x21
    jc fail_alloc
    mov [env_seg], ax
    mov es, ax

    xor di, di
    mov si, custom_var
.copy_custom:
    lodsb
    stosb
    test al, al
    jnz .copy_custom

    mov cx, 40
    mov bl, '0'
.filler_loop:
    mov al, 'F'
    stosb
    mov al, bl
    stosb
    mov al, '='
    stosb
    push cx
    mov cx, 10
    mov al, 'A'
    rep stosb
    pop cx
    xor al, al
    stosb
    inc bl
    cmp bl, '9' + 1
    jne .filler_next
    mov bl, '0'
.filler_next:
    loop .filler_loop

    xor al, al
    stosb
    mov ax, 1
    stosw
    mov si, self_path
.copy_path:
    lodsb
    stosb
    test al, al
    jnz .copy_path

    push cs
    pop es
    mov ax, [env_seg]
    mov [exec_params], ax
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

    mov dx, msg_pass
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_alloc:
    mov dx, msg_fail_alloc
    jmp fail
fail_exec:
    mov dx, msg_fail_exec
    jmp fail
fail_child:
    mov dx, msg_fail_child
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

env_seg: dw 0
custom_var: db "CUSTOM=YES", 0
self_path: db "A:\ENVCHILD.COM", 0
child_path: db "ENVCHILD.COM", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
msg_pass:       db "PASS: ENVBIG", 13, 10, '$'
msg_fail_alloc: db "FAIL: ENVBIG ALLOC", 13, 10, '$'
msg_fail_exec:  db "FAIL: ENVBIG EXEC", 13, 10, '$'
msg_fail_child: db "FAIL: ENVBIG CHILD", 13, 10, '$'
