[bits 16]
[org 0x100]

start:
    push cs
    pop ds

    mov dx, filename
    mov ax, 0x3D02
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, [handle]
    mov ax, 0x4406
    int 0x21
    jc fail_ioctl
    cmp ax, 0xFFFF
    jne fail_data

    mov bx, [handle]
    mov dx, buf
    mov cx, 1
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 1
    jne fail_read
    cmp byte [buf], 'X'
    jne fail_data

    mov bx, [handle]
    mov ax, 0x4406
    int 0x21
    jc fail_ioctl
    test ax, ax
    jnz fail_data

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_ioctl:
    mov dx, fail_ioctl_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_data:
    mov dx, fail_data_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "TEST.DAT", 0
pass_msg: db "PASS: IOCTLST", 13, 10, "$"
fail_open_msg: db "FAIL: IOCTLST OPEN", 13, 10, "$"
fail_ioctl_msg: db "FAIL: IOCTLST IOCTL", 13, 10, "$"
fail_read_msg: db "FAIL: IOCTLST READ", 13, 10, "$"
fail_data_msg: db "FAIL: IOCTLST DATA", 13, 10, "$"
handle: dw 0
buf: db 0
