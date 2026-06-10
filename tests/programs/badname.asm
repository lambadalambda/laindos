[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x3C
    xor cx, cx
    mov dx, qmark_name
    int 0x21
    jnc fail_create_q
    mov ah, 0x3C
    xor cx, cx
    mov dx, star_name
    int 0x21
    jnc fail_create_q
    mov dx, msg_create
    mov ah, 0x09
    int 0x21

    mov ah, 0x39
    mov dx, qmark_dir
    int 0x21
    jnc fail_mkdir_q
    mov dx, msg_mkdir
    mov ah, 0x09
    int 0x21

    mov ah, 0x3C
    xor cx, cx
    mov dx, good_name
    int 0x21
    jc fail_setup
    mov bx, ax
    mov ah, 0x3E
    int 0x21

    mov ah, 0x56
    mov dx, good_name
    mov di, star_target
    push ds
    pop es
    int 0x21
    jnc fail_ren_star
    mov ah, 0x56
    mov dx, good_name
    mov di, dotdot_target
    int 0x21
    jnc fail_ren_dot
    mov ah, 0x56
    mov dx, good_name
    mov di, good_target
    int 0x21
    jc fail_ren_good
    mov ax, 0x3D00
    mov dx, good_target
    int 0x21
    jc fail_ren_good
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    mov dx, msg_rename
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_create_q:
    mov dx, msg_fail_create
    jmp fail
fail_mkdir_q:
    mov dx, msg_fail_mkdir
    jmp fail
fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_ren_star:
    mov dx, msg_fail_star
    jmp fail
fail_ren_dot:
    mov dx, msg_fail_dot
    jmp fail
fail_ren_good:
    mov dx, msg_fail_good
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

qmark_name:    db "A?B.DAT", 0
star_name:     db "B*.DAT", 0
qmark_dir:     db "X?Y", 0
good_name:     db "GOODNAME.DAT", 0
star_target:   db "BA*.DAT", 0
dotdot_target: db "..", 0
good_target:   db "RENAMED.DAT", 0
msg_create:      db "PASS: BADNAME CREATE", 13, 10, '$'
msg_mkdir:       db "PASS: BADNAME MKDIR", 13, 10, '$'
msg_rename:      db "PASS: BADNAME RENAME", 13, 10, '$'
msg_fail_create: db "FAIL: BADNAME CREATE", 13, 10, '$'
msg_fail_mkdir:  db "FAIL: BADNAME MKDIR", 13, 10, '$'
msg_fail_setup:  db "FAIL: BADNAME SETUP", 13, 10, '$'
msg_fail_star:   db "FAIL: BADNAME REN STAR", 13, 10, '$'
msg_fail_dot:    db "FAIL: BADNAME REN DOTDOT", 13, 10, '$'
msg_fail_good:   db "FAIL: BADNAME REN GOOD", 13, 10, '$'
