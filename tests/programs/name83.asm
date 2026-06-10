[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x3C
    xor cx, cx
    mov dx, name9
    int 0x21
    jc fail_create
    mov bx, ax
    mov ah, 0x40
    mov cx, 4
    mov dx, tag9
    int 0x21
    mov ah, 0x3E
    int 0x21

    mov ax, 0x3D00
    mov dx, name9
    int 0x21
    jc fail_open9
    mov bx, ax
    mov ah, 0x3F
    mov cx, 4
    mov dx, read_buf
    int 0x21
    jc fail_open9
    mov ah, 0x3E
    int 0x21
    mov ax, [read_buf]
    cmp ax, [tag9]
    jne fail_open9
    mov dx, msg_nine
    mov ah, 0x09
    int 0x21

    mov ah, 0x39
    mov dx, dir11
    int 0x21
    jc fail_dir
    mov ah, 0x3B
    mov dx, dir11
    int 0x21
    jc fail_dir
    mov ah, 0x3B
    mov dx, dotdot
    int 0x21
    jc fail_dir
    mov ah, 0x3A
    mov dx, dir11
    int 0x21
    jc fail_dir
    mov dx, msg_dir
    mov ah, 0x09
    int 0x21

    mov ah, 0x3C
    xor cx, cx
    mov dx, name14
    int 0x21
    jc fail_create
    mov bx, ax
    mov ah, 0x40
    mov cx, 4
    mov dx, tag14
    int 0x21
    mov ah, 0x3E
    int 0x21

    mov ax, 0x3D00
    mov dx, name14
    int 0x21
    jc fail_long
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    mov ax, 0x3D00
    mov dx, name8
    int 0x21
    jc fail_long
    mov bx, ax
    mov ah, 0x3F
    mov cx, 4
    mov dx, read_buf
    int 0x21
    jc fail_long
    mov ah, 0x3E
    int 0x21
    mov ax, [read_buf]
    cmp ax, [tag14]
    jne fail_long
    mov dx, msg_long
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_create:
    mov dx, msg_fail_create
    jmp fail
fail_open9:
    mov dx, msg_fail_nine
    jmp fail
fail_dir:
    mov dx, msg_fail_dir
    jmp fail
fail_long:
    mov dx, msg_fail_long
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

name9:  db "DIRNAMEXX", 0
dir11:  db "LONGNAMEABC", 0
dotdot: db "..", 0
name14: db "WAYTOOLONGNAME", 0
name8:  db "WAYTOOLO", 0
tag9:   db "NIN9"
tag14:  db "LO14"
read_buf: dw 0, 0
msg_nine:        db "PASS: NAME83 NINE", 13, 10, '$'
msg_dir:         db "PASS: NAME83 DIR", 13, 10, '$'
msg_long:        db "PASS: NAME83 LONG", 13, 10, '$'
msg_fail_create: db "FAIL: NAME83 CREATE", 13, 10, '$'
msg_fail_nine:   db "FAIL: NAME83 NINE", 13, 10, '$'
msg_fail_dir:    db "FAIL: NAME83 DIR", 13, 10, '$'
msg_fail_long:   db "FAIL: NAME83 LONG", 13, 10, '$'
