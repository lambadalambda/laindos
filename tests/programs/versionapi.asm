[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x30
    int 0x21
    jc fail_get_version
    cmp al, 5
    jne fail_get_version
    cmp ah, 0
    jne fail_get_version
    cmp bx, 0
    jne fail_get_version
    cmp cx, 0
    jne fail_get_version

    mov ax, 0x3306
    mov bx, 0xFFFF
    mov dx, 0xFFFF
    int 0x21
    jc fail_true_version
    cmp bl, 5
    jne fail_true_version
    cmp bh, 0
    jne fail_true_version
    cmp dl, 0
    jne fail_true_version
    cmp dh, 0x10
    jne fail_true_version

    mov ax, 0x3307
    int 0x21
    jnc fail_bad_subfunc
    cmp ax, 1
    jne fail_bad_subfunc

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_get_version:
    mov dx, fail_get_version_msg
    jmp fail
fail_true_version:
    mov dx, fail_true_version_msg
    jmp fail
fail_bad_subfunc:
    mov dx, fail_bad_subfunc_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db "PASS: VERSIONAPI", 13, 10, "$"
fail_get_version_msg: db "FAIL: VERSIONAPI GET", 13, 10, "$"
fail_true_version_msg: db "FAIL: VERSIONAPI TRUE", 13, 10, "$"
fail_bad_subfunc_msg: db "FAIL: VERSIONAPI BADFUNC", 13, 10, "$"
