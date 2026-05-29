[bits 16]
[org 0x0100]

FAT_TIME equ 0x6000
FAT_DATE equ 0x5CB6
SET_TIME equ 0x1234
SET_DATE equ 0x5678

start:
    push cs
    pop ds
    cld

    mov dx, file_name
    mov ah, 0x41
    int 0x21

    mov dx, file_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, payload
    mov cx, payload_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, payload_size
    jne fail_write

    mov bx, [handle]
    mov ax, 0x5700
    int 0x21
    jc fail_get
    cmp cx, FAT_TIME
    jne fail_initial_time
    cmp dx, FAT_DATE
    jne fail_initial_time

    mov bx, [handle]
    mov ax, 0x5702
    int 0x21
    jnc fail_bad_subfunc
    cmp ax, 1
    jne fail_bad_subfunc

    mov bx, [handle]
    mov cx, SET_TIME
    mov dx, SET_DATE
    mov ax, 0x5701
    int 0x21
    jc fail_set

    mov bx, [handle]
    mov ax, 0x5700
    int 0x21
    jc fail_get
    cmp cx, SET_TIME
    jne fail_set_time
    cmp dx, SET_DATE
    jne fail_set_time

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, file_name
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find
    cmp word [dta + 22], SET_TIME
    jne fail_time
    cmp word [dta + 24], SET_DATE
    jne fail_time

    mov dx, file_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov ax, 0x5700
    int 0x21
    jc fail_get
    cmp cx, SET_TIME
    jne fail_reopen_time
    cmp dx, SET_DATE
    jne fail_reopen_time

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_find:
    mov dx, fail_find_msg
    jmp fail
fail_time:
    mov dx, fail_time_msg
    jmp fail
fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_get:
    mov dx, fail_get_msg
    jmp fail
fail_initial_time:
    mov dx, fail_initial_time_msg
    jmp fail
fail_bad_subfunc:
    mov dx, fail_bad_subfunc_msg
    jmp fail
fail_set:
    mov dx, fail_set_msg
    jmp fail
fail_set_time:
    mov dx, fail_set_time_msg
    jmp fail
fail_reopen_time:
    mov dx, fail_reopen_time_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
file_name: db "TIMECHK.DAT", 0
payload: db "time"
payload_size equ $ - payload
pass_msg: db "PASS: FINDTIME", 13, 10, "$"
fail_create_msg: db "FAIL: FINDTIME CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: FINDTIME WRITE", 13, 10, "$"
fail_close_msg: db "FAIL: FINDTIME CLOSE", 13, 10, "$"
fail_find_msg: db "FAIL: FINDTIME FIND", 13, 10, "$"
fail_time_msg: db "FAIL: FINDTIME TIME", 13, 10, "$"
fail_open_msg: db "FAIL: FINDTIME OPEN", 13, 10, "$"
fail_get_msg: db "FAIL: FINDTIME GET", 13, 10, "$"
fail_initial_time_msg: db "FAIL: FINDTIME INITIAL", 13, 10, "$"
fail_bad_subfunc_msg: db "FAIL: FINDTIME BADFUNC", 13, 10, "$"
fail_set_msg: db "FAIL: FINDTIME SET", 13, 10, "$"
fail_set_time_msg: db "FAIL: FINDTIME SETTIME", 13, 10, "$"
fail_reopen_time_msg: db "FAIL: FINDTIME REOPEN", 13, 10, "$"
dta: times 64 db 0
