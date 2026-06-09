[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    cld

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, all_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_first
    mov si, expected_hello
    mov di, dta + 30
    call check_name
    jc fail_first_name

    mov ah, 0x4F
    int 0x21
    jc fail_second
    mov si, expected_readme
    mov di, dta + 30
    call check_name
    jc fail_second_name

    mov ah, 0x4F
    int 0x21
    jnc fail_exhaust

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

fail_first:
    mov dx, fail_first_msg
    jmp fail
fail_first_name:
    mov dx, fail_first_name_msg
    jmp fail
fail_second:
    mov dx, fail_second_msg
    jmp fail
fail_second_name:
    mov dx, fail_second_name_msg
    jmp fail
fail_exhaust:
    mov dx, fail_exhaust_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

all_pattern: db 'D:\*.*', 0
expected_hello: db 'HELLO.TXT', 0
expected_readme: db 'README.TXT', 0
pass_msg: db 'PASS: CDFIND', 13, 10, '$'
fail_first_msg: db 'FAIL: CDFIND FIRST', 13, 10, '$'
fail_first_name_msg: db 'FAIL: CDFIND FIRST NAME', 13, 10, '$'
fail_second_msg: db 'FAIL: CDFIND SECOND', 13, 10, '$'
fail_second_name_msg: db 'FAIL: CDFIND SECOND NAME', 13, 10, '$'
fail_exhaust_msg: db 'FAIL: CDFIND EXHAUST', 13, 10, '$'
dta: times 64 db 0
