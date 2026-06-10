[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x3300
    int 0x21
    jc fail_break_get
    cmp dl, 0
    jne fail_break_get

    mov ax, 0x3301
    mov dl, 1
    int 0x21
    jc fail_break_set
    mov ax, 0x3300
    int 0x21
    jc fail_break_get
    cmp dl, 1
    jne fail_break_get

    mov ax, 0x3301
    mov dl, 2
    int 0x21
    jc fail_break_set
    mov ax, 0x3300
    int 0x21
    jc fail_break_get
    cmp dl, 0
    jne fail_break_get

    mov ax, 0x3301
    mov dl, 3
    int 0x21
    jc fail_break_set
    mov ax, 0x3300
    int 0x21
    jc fail_break_get
    cmp dl, 1
    jne fail_break_get

    mov ax, 0x3302
    int 0x21
    jnc fail_break_badfunc
    cmp ax, 1
    jne fail_break_badfunc
    mov ax, 0x3300
    int 0x21
    jc fail_break_get
    cmp dl, 1
    jne fail_break_get

    mov ax, 0x3301
    xor dl, dl
    int 0x21
    jc fail_break_set
    mov ax, 0x3305
    int 0x21
    jc fail_break_boot
    cmp dl, 1
    jne fail_break_boot
    mov ax, 0x3306
    int 0x21
    jc fail_break_ver
    cmp bx, 0x0005
    jne fail_break_ver
    cmp dx, 0x1000
    jne fail_break_ver

    mov ah, 0x54
    int 0x21
    jc fail_verify_get
    cmp al, 0
    jne fail_verify_get
    mov ax, 0x2E01
    xor dl, dl
    int 0x21
    jc fail_verify_set
    mov ah, 0x54
    int 0x21
    jc fail_verify_get
    cmp al, 1
    jne fail_verify_get
    mov ax, 0x2E03
    mov dl, 0xFF
    int 0x21
    jc fail_verify_set
    mov ah, 0x54
    int 0x21
    jc fail_verify_get
    cmp al, 1
    jne fail_verify_get
    mov ax, 0x2E02
    mov dl, 0xFF
    int 0x21
    jc fail_verify_set
    mov ah, 0x54
    int 0x21
    jc fail_verify_get
    cmp al, 0
    jne fail_verify_get
    mov ax, 0x2E01
    xor dl, dl
    int 0x21
    jc fail_verify_set
    mov ah, 0x54
    int 0x21
    jc fail_verify_get
    cmp al, 1
    jne fail_verify_get
    mov ax, 0x2E00
    mov dl, 1
    int 0x21
    jc fail_verify_set
    mov ah, 0x54
    int 0x21
    jc fail_verify_get
    cmp al, 0
    jne fail_verify_get

    mov cx, 2027
    mov dh, 12
    mov dl, 31
    mov ah, 0x2B
    int 0x21
    cmp al, 0
    jne fail_set_date
    mov ah, 0x2A
    int 0x21
    cmp cx, 2027
    jne fail_get_date
    cmp dh, 12
    jne fail_get_date
    cmp dl, 31
    jne fail_get_date

    mov cx, 2028
    mov dh, 2
    mov dl, 29
    mov ah, 0x2B
    int 0x21
    cmp al, 0
    jne fail_set_date
    mov ah, 0x2A
    int 0x21
    cmp cx, 2028
    jne fail_get_date
    cmp dh, 2
    jne fail_get_date
    cmp dl, 29
    jne fail_get_date

    mov cx, 2027
    mov dh, 2
    mov dl, 29
    mov ah, 0x2B
    int 0x21
    cmp al, 0xFF
    jne fail_bad_date
    mov ah, 0x2A
    int 0x21
    cmp cx, 2028
    jne fail_get_date
    cmp dh, 2
    jne fail_get_date
    cmp dl, 29
    jne fail_get_date

    mov ch, 11
    mov cl, 22
    mov dh, 33
    mov dl, 44
    mov ah, 0x2D
    int 0x21
    cmp al, 0
    jne fail_set_time
    mov ah, 0x2C
    int 0x21
    cmp ch, 11
    jne fail_get_time
    cmp cl, 22
    jne fail_get_time
    cmp dh, 33
    jne fail_get_time
    cmp dl, 39
    jb fail_get_time

    mov ch, 24
    xor cl, cl
    xor dh, dh
    xor dl, dl
    mov ah, 0x2D
    int 0x21
    cmp al, 0xFF
    jne fail_bad_time
    mov ah, 0x2C
    int 0x21
    cmp ch, 11
    jne fail_get_time
    cmp cl, 22
    jne fail_get_time

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_break_get:
    mov dx, fail_break_get_msg
    jmp fail
fail_break_set:
    mov dx, fail_break_set_msg
    jmp fail
fail_break_badfunc:
    mov dx, fail_break_badfunc_msg
    jmp fail
fail_break_boot:
    mov dx, fail_break_boot_msg
    jmp fail
fail_break_ver:
    mov dx, fail_break_ver_msg
    jmp fail
fail_verify_get:
    mov dx, fail_verify_get_msg
    jmp fail
fail_verify_set:
    mov dx, fail_verify_set_msg
    jmp fail
fail_set_date:
    mov dx, fail_set_date_msg
    jmp fail
fail_get_date:
    mov dx, fail_get_date_msg
    jmp fail
fail_bad_date:
    mov dx, fail_bad_date_msg
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

pass_msg: db 'PASS: STATEAPI', 13, 10, '$'
fail_break_get_msg: db 'FAIL: STATEAPI BREAK GET', 13, 10, '$'
fail_break_set_msg: db 'FAIL: STATEAPI BREAK SET', 13, 10, '$'
fail_break_badfunc_msg: db 'FAIL: STATEAPI BREAK BADFUNC', 13, 10, '$'
fail_break_boot_msg: db 'FAIL: STATEAPI BOOT', 13, 10, '$'
fail_break_ver_msg: db 'FAIL: STATEAPI VERSION', 13, 10, '$'
fail_verify_get_msg: db 'FAIL: STATEAPI VERIFY GET', 13, 10, '$'
fail_verify_set_msg: db 'FAIL: STATEAPI VERIFY SET', 13, 10, '$'
fail_set_date_msg: db 'FAIL: STATEAPI SET DATE', 13, 10, '$'
fail_get_date_msg: db 'FAIL: STATEAPI GET DATE', 13, 10, '$'
fail_bad_date_msg: db 'FAIL: STATEAPI BAD DATE', 13, 10, '$'
fail_set_time_msg: db 'FAIL: STATEAPI SET TIME', 13, 10, '$'
fail_get_time_msg: db 'FAIL: STATEAPI GET TIME', 13, 10, '$'
fail_bad_time_msg: db 'FAIL: STATEAPI BAD TIME', 13, 10, '$'
