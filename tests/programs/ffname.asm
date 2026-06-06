[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, dta_buf
    mov ah, 0x1A
    int 0x21

    mov dx, find_e5_pattern
    mov ah, 0x4E
    mov cx, 0x20
    int 0x21
    pushf
    push ax
    add al, '0'
    cmp al, '9'
    jbe .ok1
    add al, 7
.ok1:
    mov [ret_char], al
    pop ax
    mov dx, ret_msg
    mov ah, 0x09
    int 0x21
    popf
    jc fail_find_e5

    mov si, expected_e5
    mov di, dta_buf+30
    mov cx, 8
    repe cmpsb
    jne fail_e5_name

    mov dx, find_nul_pattern
    mov ah, 0x4E
    mov cx, 0x20
    int 0x21
    jc fail_find_nul

    mov si, expected_nul
    mov di, dta_buf+30
    mov cx, 8
    repe cmpsb
    jne fail_nul_name

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_find_e5:
    mov dx, fail_find_e5_msg
    jmp fail
fail_e5_name:
    mov dx, fail_e5_name_msg
    jmp fail
fail_find_nul:
    mov dx, fail_find_nul_msg
    jmp fail
fail_nul_name:
    mov dx, fail_nul_name_msg
    jmp fail

fail:
    push ds
    pop es
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

find_e5_pattern: db "N??????.TXT", 0
find_nul_pattern: db "NUL?FILE.TXT", 0
expected_e5: db "NORMA", 0x05, "L", "."
expected_nul: db "NUL?", "FILE", "."
dta_buf: times 128 db 0
pass_msg: db "PASS: FFNAME", 13, 10, "$"
ret_msg: db "R="
ret_char: db "0", 13, 10, "$"
fail_find_e5_msg: db "FAIL: FFNAME FIND E5", 13, 10, "$"
fail_e5_name_msg: db "FAIL: FFNAME E5 NAME", 13, 10, "$"
fail_find_nul_msg: db "FAIL: FFNAME FIND NUL", 13, 10, "$"
fail_nul_name_msg: db "FAIL: FFNAME NUL NAME", 13, 10, "$"
