[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x2B00
    mov cx, 2026
    mov dh, 6
    mov dl, 10
    int 0x21
    test al, al
    jnz fail_setup

    mov ah, 0x2D
    mov ch, 12
    mov cl, 30
    mov dh, 0
    mov dl, 0
    int 0x21
    test al, al
    jnz fail_setup

    mov ah, 0x2C
    int 0x21
    cmp ch, 12
    jne fail_set
    cmp cl, 30
    jne fail_set
    mov [first_sec], dh
    mov dx, msg_set
    mov ah, 0x09
    int 0x21

    call wait_ticks
    mov ah, 0x2C
    int 0x21
    cmp ch, 12
    jne fail_advance
    cmp dh, [first_sec]
    je fail_advance
    mov dx, msg_advance
    mov ah, 0x09
    int 0x21

    mov ah, 0x2D
    mov ch, 23
    mov cl, 59
    mov dh, 59
    mov dl, 0
    int 0x21
    test al, al
    jnz fail_setup

    call wait_ticks
    mov ah, 0x2C
    int 0x21
    cmp ch, 0
    jne fail_midnight
    mov ah, 0x2A
    int 0x21
    cmp dl, 11
    jne fail_date
    cmp dh, 6
    jne fail_date
    mov dx, msg_midnight
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

wait_ticks:
    push ax
    push bx
    push cx
    push dx
    xor ah, ah
    int 0x1A
    mov bx, dx
.tick_loop:
    xor ah, ah
    int 0x1A
    sub dx, bx
    cmp dx, 60
    jb .tick_loop
    pop dx
    pop cx
    pop bx
    pop ax
    ret

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_set:
    mov dx, msg_fail_set
    jmp fail
fail_advance:
    mov dx, msg_fail_advance
    jmp fail
fail_midnight:
    mov dx, msg_fail_midnight
    jmp fail
fail_date:
    mov dx, msg_fail_date
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

first_sec: db 0
msg_set:           db "PASS: CLOCK SET", 13, 10, '$'
msg_advance:       db "PASS: CLOCK ADVANCE", 13, 10, '$'
msg_midnight:      db "PASS: CLOCK MIDNIGHT", 13, 10, '$'
msg_fail_setup:    db "FAIL: CLOCK SETUP", 13, 10, '$'
msg_fail_set:      db "FAIL: CLOCK SET", 13, 10, '$'
msg_fail_advance:  db "FAIL: CLOCK ADVANCE", 13, 10, '$'
msg_fail_midnight: db "FAIL: CLOCK MIDNIGHT", 13, 10, '$'
msg_fail_date:     db "FAIL: CLOCK DATE", 13, 10, '$'
