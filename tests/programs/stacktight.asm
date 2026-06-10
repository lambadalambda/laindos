[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x3C
    xor cx, cx
    mov dx, fname
    int 0x21
    jc fail_setup
    mov bx, ax
    mov cx, 4
.fill:
    push cx
    mov ah, 0x40
    mov cx, 512
    mov dx, filebuf
    int 0x21
    pop cx
    jc fail_setup
    loop .fill
    mov ah, 0x3E
    int 0x21
    jc fail_setup

    mov di, guard
    mov cx, 32
    mov al, 0xA5
    rep stosb

    cli
    mov ax, cs
    mov ss, ax
    mov sp, tight_top
    sti

    mov ax, 0x3D02
    mov dx, fname
    int 0x21
    jc fail_ops
    mov [handle], ax
    mov bx, ax
    mov ah, 0x3F
    mov cx, 1024
    mov dx, filebuf
    int 0x21
    jc fail_ops
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov al, 2
    mov ah, 0x42
    int 0x21
    jc fail_ops
    mov bx, [handle]
    mov ah, 0x40
    mov cx, 512
    mov dx, filebuf
    int 0x21
    jc fail_ops
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_ops
    mov ah, 0x39
    mov dx, dname
    int 0x21
    jc fail_ops
    mov ah, 0x3A
    mov dx, dname
    int 0x21
    jc fail_ops

    cli
    mov ax, cs
    mov ss, ax
    mov sp, big_top
    sti

    mov si, guard
    mov cx, 32
.check:
    cmp byte [si], 0xA5
    jne fail_guard
    inc si
    loop .check

    mov dx, msg_pass
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_ops:
    cli
    mov ax, cs
    mov ss, ax
    mov sp, big_top
    sti
    mov dx, msg_fail_ops
    jmp fail
fail_guard:
    mov dx, msg_fail_guard
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
fname: db "TIGHT.DAT", 0
dname: db "TIGHTDIR", 0
msg_pass:       db "PASS: STACKTIGHT", 13, 10, '$'
msg_fail_setup: db "FAIL: STACKTIGHT SETUP", 13, 10, '$'
msg_fail_ops:   db "FAIL: STACKTIGHT OPS", 13, 10, '$'
msg_fail_guard: db "FAIL: STACKTIGHT GUARD", 13, 10, '$'

guard: times 32 db 0
tight_stack: times 128 db 0
tight_top:

big_stack: times 256 db 0
big_top:

filebuf: times 1024 db 0x42
