[bits 16]
[org 0x0100]

start:
    mov si, expected
    mov di, 0x81
    xor cx, cx
    mov cl, [0x80]
    cmp cl, expected_len
    jne fail
.loop:
    lodsb
    cmp al, [di]
    jne fail
    inc di
    loop .loop
    mov ah, 0x09
    mov dx, pass_msg
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail:
    mov ah, 0x09
    mov dx, fail_msg
    int 0x21
    mov ax, 0x4C01
    int 0x21

expected: db " GDEMO /3"
expected_len equ $ - expected
pass_msg: db "PASS: ARGTEST", 13, 10, "$"
fail_msg: db "FAIL: ARGTEST", 13, 10, "$"
