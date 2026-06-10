org 0x100

start:
    push cs
    pop ds

    mov ah, 0x39
    mov dx, dirname
    int 0x21
    jc fail_setup

    mov ax, 0x3D02
    mov dx, dirname
    int 0x21
    jnc fail_dir_open
    cmp ax, 5
    jne fail_dir_open
    mov ax, 0x3D00
    mov dx, dirname
    int 0x21
    jnc fail_dir_open
    cmp ax, 5
    jne fail_dir_open
    mov dx, msg_dir
    mov ah, 0x09
    int 0x21

    mov ah, 0x3C
    xor cx, cx
    mov dx, filename
    int 0x21
    jc fail_setup
    mov bx, ax
    mov ah, 0x40
    mov cx, 4
    mov dx, filedata
    int 0x21
    jc fail_setup
    mov ah, 0x3E
    int 0x21

    mov ax, 0x4301
    mov cx, 0x0001
    mov dx, filename
    int 0x21
    jc fail_setup

    mov ax, 0x3D01
    mov dx, filename
    int 0x21
    jnc fail_ro_open
    cmp ax, 5
    jne fail_ro_open
    mov ax, 0x3D02
    mov dx, filename
    int 0x21
    jnc fail_ro_open
    cmp ax, 5
    jne fail_ro_open
    mov ax, 0x3D00
    mov dx, filename
    int 0x21
    jc fail_ro_open
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    mov dx, msg_ro
    mov ah, 0x09
    int 0x21

    mov ax, 0x4301
    xor cx, cx
    mov dx, filename
    int 0x21
    jc fail_setup

    mov ax, 0x3D40
    mov dx, filename
    int 0x21
    jc fail_share_open
    mov bx, ax
    mov ah, 0x40
    mov cx, 4
    mov dx, filedata
    int 0x21
    jnc fail_share_write
    cmp ax, 5
    jne fail_share_write
    mov ah, 0x3E
    int 0x21
    mov dx, msg_share
    mov ah, 0x09
    int 0x21

    mov ax, 0x3D01
    mov dx, filename
    int 0x21
    jc fail_rw_open
    mov bx, ax
    mov ah, 0x40
    mov cx, 4
    mov dx, filedata
    int 0x21
    jc fail_rw_open
    cmp ax, 4
    jne fail_rw_open
    mov ah, 0x3E
    int 0x21
    mov dx, msg_write
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_dir_open:
    mov dx, msg_fail_dir
    jmp fail
fail_ro_open:
    mov dx, msg_fail_ro
    jmp fail
fail_share_open:
    mov dx, msg_fail_share
    jmp fail
fail_share_write:
    mov dx, msg_fail_share_wr
    jmp fail
fail_rw_open:
    mov dx, msg_fail_write
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

dirname:  db "ATTRDIR", 0
filename: db "ATTRFILE.DAT", 0
filedata: db "data"
msg_dir:           db "PASS: OPENATTR DIR", 13, 10, '$'
msg_ro:            db "PASS: OPENATTR RO", 13, 10, '$'
msg_share:         db "PASS: OPENATTR SHARE", 13, 10, '$'
msg_write:         db "PASS: OPENATTR WRITE", 13, 10, '$'
msg_fail_setup:    db "FAIL: OPENATTR SETUP", 13, 10, '$'
msg_fail_dir:      db "FAIL: OPENATTR DIR", 13, 10, '$'
msg_fail_ro:       db "FAIL: OPENATTR RO", 13, 10, '$'
msg_fail_share:    db "FAIL: OPENATTR SHARE", 13, 10, '$'
msg_fail_share_wr: db "FAIL: OPENATTR SHARE WRITE", 13, 10, '$'
msg_fail_write:    db "FAIL: OPENATTR WRITE", 13, 10, '$'
