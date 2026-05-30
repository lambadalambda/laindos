[bits 16]
[org 0x0100]

start:
    mov ax, 0x6300
    int 0x21
    jc fail_get
    cmp al, 0
    jne fail_get
    cmp byte [ds:si], 0
    jne fail_table

    mov ax, 0x6301
    int 0x21
    jnc fail_bad_subfunc

    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_get:
    push cs
    pop ds
    mov dx, fail_get_msg
    jmp fail
fail_table:
    push cs
    pop ds
    mov dx, fail_table_msg
    jmp fail
fail_bad_subfunc:
    push cs
    pop ds
    mov dx, fail_subfunc_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db "PASS: DBCS", 13, 10, "$"
fail_get_msg: db "FAIL: DBCS GET", 13, 10, "$"
fail_table_msg: db "FAIL: DBCS TABLE", 13, 10, "$"
fail_subfunc_msg: db "FAIL: DBCS SUBFUNC", 13, 10, "$"
