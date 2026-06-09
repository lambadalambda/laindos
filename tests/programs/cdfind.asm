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

    mov dx, explicit_subdir_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_explicit_subdir_first
    mov si, expected_driver
    mov di, dta + 30
    call check_name
    jc fail_explicit_subdir_name

    mov ah, 0x4F
    int 0x21
    jnc fail_explicit_subdir_exhaust

    mov dx, subdir_path
    mov ah, 0x3B
    int 0x21
    jc fail_subdir_chdir

    mov dl, 3
    mov ah, 0x0E
    int 0x21

    mov dx, subdir_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_subdir_first
    mov si, expected_driver
    mov di, dta + 30
    call check_name
    jc fail_subdir_name

    mov ah, 0x4F
    int 0x21
    jnc fail_subdir_exhaust

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
    jmp fail
fail_subdir_chdir:
    mov dx, fail_subdir_chdir_msg
    jmp fail
fail_explicit_subdir_first:
    mov dx, fail_explicit_subdir_first_msg
    jmp fail
fail_explicit_subdir_name:
    mov dx, fail_explicit_subdir_name_msg
    jmp fail
fail_explicit_subdir_exhaust:
    mov dx, fail_explicit_subdir_exhaust_msg
    jmp fail
fail_subdir_first:
    mov dx, fail_subdir_first_msg
    jmp fail
fail_subdir_name:
    mov dx, fail_subdir_name_msg
    jmp fail
fail_subdir_exhaust:
    mov dx, fail_subdir_exhaust_msg
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
expected_driver: db 'DRIVER.MSD', 0
explicit_subdir_pattern: db 'D:\SUBDIR\*.MSD', 0
subdir_path: db 'D:\SUBDIR', 0
subdir_pattern: db '*.MSD', 0
pass_msg: db 'PASS: CDFIND', 13, 10, '$'
fail_first_msg: db 'FAIL: CDFIND FIRST', 13, 10, '$'
fail_first_name_msg: db 'FAIL: CDFIND FIRST NAME', 13, 10, '$'
fail_second_msg: db 'FAIL: CDFIND SECOND', 13, 10, '$'
fail_second_name_msg: db 'FAIL: CDFIND SECOND NAME', 13, 10, '$'
fail_exhaust_msg: db 'FAIL: CDFIND EXHAUST', 13, 10, '$'
fail_explicit_subdir_first_msg: db 'FAIL: CDFIND EXPL SUBDIR FIRST', 13, 10, '$'
fail_explicit_subdir_name_msg: db 'FAIL: CDFIND EXPL SUBDIR NAME', 13, 10, '$'
fail_explicit_subdir_exhaust_msg: db 'FAIL: CDFIND EXPL SUBDIR EXHAUST', 13, 10, '$'
fail_subdir_chdir_msg: db 'FAIL: CDFIND SUBDIR CHDIR', 13, 10, '$'
fail_subdir_first_msg: db 'FAIL: CDFIND SUBDIR FIRST', 13, 10, '$'
fail_subdir_name_msg: db 'FAIL: CDFIND SUBDIR NAME', 13, 10, '$'
fail_subdir_exhaust_msg: db 'FAIL: CDFIND SUBDIR EXHAUST', 13, 10, '$'
dta: times 64 db 0
