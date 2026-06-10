[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x3C
    xor cx, cx
    mov dx, cfile
    int 0x21
    jc fail_setup
    mov [handle], ax

    mov ax, 0x4300
    mov dx, afile
    int 0x21
    jc fail_setup

    mov bx, [handle]
    mov ax, 0x4400
    int 0x21
    jc fail_drive
    and dx, 0x003F
    cmp dx, 2
    jne fail_drive
    mov dx, msg_drive
    mov ah, 0x09
    int 0x21

    mov bx, 1
    mov dx, 0x0034
    mov ax, 0x4401
    int 0x21
    jc fail_set
    cmp dx, 0x0034
    jne fail_set
    mov dx, msg_set
    mov ah, 0x09
    int 0x21

    mov bx, [handle]
    mov dx, 0x0020
    mov ax, 0x4401
    int 0x21
    jc fail_setfile
    cmp dx, 0x0020
    jne fail_setfile
    mov bx, [handle]
    mov dx, 0x0120
    mov ax, 0x4401
    int 0x21
    jnc fail_setfile
    cmp ax, 1
    jne fail_setfile
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    mov dx, msg_setfile
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_drive:
    mov dx, msg_fail_drive
    jmp fail
fail_set:
    mov dx, msg_fail_set
    jmp fail
fail_setfile:
    mov dx, msg_fail_setfile
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
cfile: db "C:IOCTL2.DAT", 0
afile: db "A:AONLY.TXT", 0
msg_drive:        db "PASS: IOCTL2 DRIVE", 13, 10, '$'
msg_set:          db "PASS: IOCTL2 SET", 13, 10, '$'
msg_setfile:      db "PASS: IOCTL2 SETFILE", 13, 10, '$'
msg_fail_setup:   db "FAIL: IOCTL2 SETUP", 13, 10, '$'
msg_fail_drive:   db "FAIL: IOCTL2 DRIVE", 13, 10, '$'
msg_fail_set:     db "FAIL: IOCTL2 SET", 13, 10, '$'
msg_fail_setfile: db "FAIL: IOCTL2 SETFILE", 13, 10, '$'
