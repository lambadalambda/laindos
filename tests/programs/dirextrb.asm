[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, new_file
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jnc fail_unexpected_create

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_unexpected_create:
    mov dx, fail_unexpected_create_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

new_file: db "FULLDIR\NEWFILE.DAT", 0
pass_msg: db "PASS: DIREXTROLL", 13, 10, "$"
fail_unexpected_create_msg: db "FAIL: DIREXTROLL CREATE", 13, 10, "$"
