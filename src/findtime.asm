[bits 16]
[org 0x0100]

FAT_TIME equ 0x6000
FAT_DATE equ 0x5CB6

start:
    push cs
    pop ds

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
    cmp word [dta + 22], FAT_TIME
    jne fail_time
    cmp word [dta + 24], FAT_DATE
    jne fail_time

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
dta: times 64 db 0
