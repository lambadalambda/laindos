[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x41
    mov dx, fname
    int 0x21
    jc fail_del

    mov ax, 0x3D00
    mov dx, fname
    int 0x21
    jnc fail_gone
    cmp ax, 2
    jne fail_gone
    mov dx, msg_del
    mov ah, 0x09
    int 0x21

    mov ah, 0x3C
    xor cx, cx
    mov dx, newname
    int 0x21
    jc fail_create
    mov bx, ax
    mov ah, 0x40
    mov cx, 16
    mov dx, fname
    int 0x21
    jc fail_create
    mov ah, 0x3E
    int 0x21
    jc fail_create
    mov dx, msg_create
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_del:
    mov dx, msg_fail_del
    jmp fail
fail_gone:
    mov dx, msg_fail_gone
    jmp fail
fail_create:
    mov dx, msg_fail_create
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fname: db "BADCLUS.DAT", 0
newname: db "AFTER.DAT", 0
msg_del:         db "PASS: BADCLUS DEL", 13, 10, '$'
msg_create:      db "PASS: BADCLUS CREATE", 13, 10, '$'
msg_fail_del:    db "FAIL: BADCLUS DEL", 13, 10, '$'
msg_fail_gone:   db "FAIL: BADCLUS GONE", 13, 10, '$'
msg_fail_create: db "FAIL: BADCLUS CREATE", 13, 10, '$'
