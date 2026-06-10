[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x3700
    mov dx, 0xFFFF
    int 0x21
    jc fail_get
    cmp al, 0
    jne fail_get
    cmp dl, '/'
    jne fail_get

    mov ax, 0x3701
    mov dl, '-'
    int 0x21
    jc fail_set
    mov ax, 0x3700
    int 0x21
    jc fail_set
    cmp dl, '-'
    jne fail_set

    mov ax, 0x3701
    mov dl, '/'
    int 0x21
    jc fail_set

    mov ax, 0x3702
    int 0x21
    cmp al, 0xFF
    jne fail_bad_subfunc

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_get:
    mov dx, fail_get_msg
    jmp fail
fail_set:
    mov dx, fail_set_msg
    jmp fail
fail_bad_subfunc:
    mov dx, fail_bad_subfunc_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db "PASS: SWITCHAR", 13, 10, "$"
fail_get_msg: db "FAIL: SWITCHAR GET", 13, 10, "$"
fail_set_msg: db "FAIL: SWITCHAR SET", 13, 10, "$"
fail_bad_subfunc_msg: db "FAIL: SWITCHAR BADFUNC", 13, 10, "$"
