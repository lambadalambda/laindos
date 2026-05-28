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

    mov dx, root_file
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_root_create
    mov [handle], ax

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_unexpected_create:
    mov dx, fail_unexpected_create_msg
    jmp fail
fail_root_create:
    mov dx, fail_root_create_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
new_file: db "FULLDIR\NEWFILE.DAT", 0
root_file: db "AFTER.TMP", 0
pass_msg: db "PASS: DIREXTFAIL", 13, 10, "$"
fail_unexpected_create_msg: db "FAIL: DIREXTFAIL CREATE", 13, 10, "$"
fail_root_create_msg: db "FAIL: DIREXTFAIL ROOT", 13, 10, "$"
fail_close_msg: db "FAIL: DIREXTFAIL CLOSE", 13, 10, "$"
