[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x2524
    mov dx, int24_handler
    int 0x21

    mov ah, 0x3C
    xor cx, cx
    mov dx, fname
    int 0x21
    jnc fail_created

    cmp byte [hit_count], 2
    jb fail_count
    cmp byte [seen_op], 3
    jne fail_op
    cmp byte [seen_drv], 0
    jne fail_drv

    mov dx, ok_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_created:
    mov dx, fail_created_msg
    jmp fail
fail_count:
    mov dx, fail_count_msg
    jmp fail
fail_op:
    mov dx, fail_op_msg
    jmp fail
fail_drv:
    mov dx, fail_drv_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

int24_handler:
    inc byte [cs:hit_count]
    mov [cs:seen_op], al
    mov [cs:seen_drv], ah
    cmp byte [cs:hit_count], 1
    jne .fail_op
    mov al, 1
    iret
.fail_op:
    mov al, 3
    iret

hit_count: db 0
seen_op: db 0xFF
seen_drv: db 0xFF
fname: db "CRITERR.DAT", 0
ok_msg: db 'PASS: INT24H', 13, 10, '$'
fail_created_msg: db 'FAIL: INT24H CREATED', 13, 10, '$'
fail_count_msg: db 'FAIL: INT24H COUNT', 13, 10, '$'
fail_op_msg: db 'FAIL: INT24H OP', 13, 10, '$'
fail_drv_msg: db 'FAIL: INT24H DRV', 13, 10, '$'
