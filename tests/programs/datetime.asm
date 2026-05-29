[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov cx, 2024
    mov dh, 2
    mov dl, 29
    mov ah, 0x2B
    int 0x21
    cmp al, 0
    jne fail_set_date
    mov ah, 0x2A
    int 0x21
    cmp cx, 2024
    jne fail_get_date
    cmp dh, 2
    jne fail_get_date
    cmp dl, 29
    jne fail_get_date
    cmp al, 4
    jne fail_weekday

    mov cx, 2024
    mov dh, 2
    mov dl, 30
    mov ah, 0x2B
    int 0x21
    cmp al, 0xFF
    jne fail_bad_date
    mov ah, 0x2A
    int 0x21
    cmp cx, 2024
    jne fail_date_preserve
    cmp dh, 2
    jne fail_date_preserve
    cmp dl, 29
    jne fail_date_preserve
    cmp al, 4
    jne fail_date_preserve

    mov cx, 1980
    mov dh, 1
    mov dl, 1
    mov ah, 0x2B
    int 0x21
    cmp al, 0
    jne fail_set_date
    mov ah, 0x2A
    int 0x21
    cmp cx, 1980
    jne fail_get_date
    cmp dh, 1
    jne fail_get_date
    cmp dl, 1
    jne fail_get_date
    cmp al, 2
    jne fail_weekday

    mov cx, 2000
    mov dh, 3
    mov dl, 1
    mov ah, 0x2B
    int 0x21
    cmp al, 0
    jne fail_set_date
    mov ah, 0x2A
    int 0x21
    cmp cx, 2000
    jne fail_get_date
    cmp dh, 3
    jne fail_get_date
    cmp dl, 1
    jne fail_get_date
    cmp al, 3
    jne fail_weekday

    mov ch, 0
    mov cl, 0
    mov dh, 0
    mov dl, 0
    mov ah, 0x2D
    int 0x21
    cmp al, 0
    jne fail_set_time
    mov ah, 0x2C
    int 0x21
    cmp cx, 0
    jne fail_get_time
    cmp dx, 0
    jne fail_get_time

    mov ch, 23
    mov cl, 59
    mov dh, 59
    mov dl, 99
    mov ah, 0x2D
    int 0x21
    cmp al, 0
    jne fail_set_time
    mov ah, 0x2C
    int 0x21
    cmp ch, 23
    jne fail_get_time
    cmp cl, 59
    jne fail_get_time
    cmp dh, 59
    jne fail_get_time
    cmp dl, 99
    jne fail_get_time

    mov ch, 24
    mov cl, 0
    mov dh, 0
    mov dl, 0
    call expect_bad_time_preserves
    jc fail_bad_time

    mov ch, 23
    mov cl, 60
    mov dh, 0
    mov dl, 0
    call expect_bad_time_preserves
    jc fail_bad_time

    mov ch, 23
    mov cl, 59
    mov dh, 60
    mov dl, 0
    call expect_bad_time_preserves
    jc fail_bad_time

    mov ch, 23
    mov cl, 59
    mov dh, 59
    mov dl, 100
    call expect_bad_time_preserves
    jc fail_bad_time

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

expect_bad_time_preserves:
    mov ah, 0x2D
    int 0x21
    cmp al, 0xFF
    jne .bad
    mov ah, 0x2C
    int 0x21
    cmp ch, 23
    jne .bad
    cmp cl, 59
    jne .bad
    cmp dh, 59
    jne .bad
    cmp dl, 99
    jne .bad
    clc
    ret
.bad:
    stc
    ret

fail_set_date:
    mov dx, fail_set_date_msg
    jmp fail
fail_get_date:
    mov dx, fail_get_date_msg
    jmp fail
fail_weekday:
    mov dx, fail_weekday_msg
    jmp fail
fail_bad_date:
    mov dx, fail_bad_date_msg
    jmp fail
fail_date_preserve:
    mov dx, fail_date_preserve_msg
    jmp fail
fail_set_time:
    mov dx, fail_set_time_msg
    jmp fail
fail_get_time:
    mov dx, fail_get_time_msg
    jmp fail
fail_bad_time:
    mov dx, fail_bad_time_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db "PASS: DATETIME", 13, 10, "$"
fail_set_date_msg: db "FAIL: DATETIME SET DATE", 13, 10, "$"
fail_get_date_msg: db "FAIL: DATETIME GET DATE", 13, 10, "$"
fail_weekday_msg: db "FAIL: DATETIME WEEKDAY", 13, 10, "$"
fail_bad_date_msg: db "FAIL: DATETIME BAD DATE", 13, 10, "$"
fail_date_preserve_msg: db "FAIL: DATETIME DATE PRESERVE", 13, 10, "$"
fail_set_time_msg: db "FAIL: DATETIME SET TIME", 13, 10, "$"
fail_get_time_msg: db "FAIL: DATETIME GET TIME", 13, 10, "$"
fail_bad_time_msg: db "FAIL: DATETIME BAD TIME", 13, 10, "$"
