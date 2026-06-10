[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x3D00
    mov dx, dot_path
    int 0x21
    jc fail_dots
    mov bx, ax
    mov ah, 0x3F
    mov cx, 4
    mov dx, read_buf
    int 0x21
    jc fail_dots
    mov ah, 0x3E
    int 0x21
    cmp word [read_buf], 'si'
    jne fail_dots
    cmp word [read_buf+2], 'bl'
    jne fail_dots
    mov dx, msg_dots
    mov ah, 0x09
    int 0x21

    mov ax, 0x3D00
    mov dx, big_path
    int 0x21
    jc fail_big
    mov bx, ax
    mov ah, 0x3F
    mov cx, 4
    mov dx, read_buf
    int 0x21
    jc fail_big
    mov ah, 0x3E
    int 0x21
    cmp word [read_buf], 'la'
    jne fail_big
    cmp word [read_buf+2], 'st'
    jne fail_big
    mov dx, msg_big
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_dots:
    mov dx, msg_fail_dots
    jmp fail
fail_big:
    mov dx, msg_fail_big
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

dot_path: db "D:D1\D2\..\SIBL.TXT", 0
big_path: db "D:BIG\LAST.TXT", 0
read_buf: times 6 db 0
msg_dots:      db "PASS: CDDOTS PARENT", 13, 10, '$'
msg_big:       db "PASS: CDDOTS BIGDIR", 13, 10, '$'
msg_fail_dots: db "FAIL: CDDOTS PARENT", 13, 10, '$'
msg_fail_big:  db "FAIL: CDDOTS BIGDIR", 13, 10, '$'
