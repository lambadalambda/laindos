[bits 16]
[org 0x100]

start:
    mov ax, ds
    cli
    mov ss, ax
    mov sp, 0x0F00
    sti

    mov ax, ds
    add ax, 0x0100
    mov [expected_top], ax
    mov ax, ds
    mov es, ax
    mov bx, 0x0100
    mov ah, 0x4A
    int 0x21
    jc fail
    mov ax, [0x02]
    cmp ax, [expected_top]
    jne fail

    mov ax, 0x7777
    mov es, ax
    mov bx, 0x0030
    mov cx, 0x1357
    mov dx, 0x2468
    mov di, 0x369A
    mov ah, 0x48
    int 0x21
    jc fail
    mov [alloc_seg], ax
    mov ax, es
    cmp ax, 0x7777
    jne fail
    cmp bx, 0x0030
    jne fail
    cmp cx, 0x1357
    jne fail
    cmp dx, 0x2468
    jne fail
    cmp di, 0x369A
    jne fail

    mov ax, [alloc_seg]
    mov es, ax
    mov ah, 0x49
    int 0x21
    jc fail

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail:
    push cs
    pop ds
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

expected_top: dw 0
alloc_seg: dw 0
pass_msg: db "PASS: MEMREG", 13, 10, "$"
fail_msg: db "FAIL: MEMREG", 13, 10, "$"
