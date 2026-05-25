[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, dta_txt
    mov ah, 0x1A
    int 0x21

    mov dx, txt_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find_txt
    mov si, expected_a
    mov di, dta_txt + 30
    call check_name
    jc fail_find_txt

    mov dx, dta_com
    mov ah, 0x1A
    int 0x21

    mov dx, zcom_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find_com
    mov si, expected_z
    mov di, dta_com + 30
    call check_name
    jc fail_find_com

    mov dx, dta_txt
    mov ah, 0x1A
    int 0x21

    mov ah, 0x4F
    int 0x21
    jc fail_next_txt
    mov si, expected_b
    mov di, dta_txt + 30
    call check_name
    jc fail_next_txt

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

check_name:
    lodsb
    cmp al, [di]
    jne .bad
    inc di
    test al, al
    jnz check_name
    clc
    ret
.bad:
    stc
    ret

fail_find_txt:
    mov dx, fail_find_txt_msg
    jmp fail
fail_find_com:
    mov dx, fail_find_com_msg
    jmp fail
fail_next_txt:
    mov dx, fail_next_txt_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

txt_pattern: db "*.TXT", 0
zcom_pattern: db "Z*.COM", 0
expected_a: db "A.TXT", 0
expected_b: db "B.TXT", 0
expected_z: db "Z.COM", 0
pass_msg: db "PASS: FINDNEXT", 13, 10, "$"
fail_find_txt_msg: db "FAIL: FINDNEXT FIRST TXT", 13, 10, "$"
fail_find_com_msg: db "FAIL: FINDNEXT COM", 13, 10, "$"
fail_next_txt_msg: db "FAIL: FINDNEXT NEXT TXT", 13, 10, "$"
dta_txt: times 64 db 0
dta_com: times 64 db 0
