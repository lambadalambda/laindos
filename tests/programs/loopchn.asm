[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ax, 0x3D00
    mov dx, fname
    int 0x21
    jnc fail_found
    cmp ax, 2
    je pass
    cmp ax, 5
    jne fail_code

pass:
    mov dx, msg_pass
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_found:
    mov dx, msg_fail_found
    jmp fail
fail_code:
    mov dx, msg_fail_code
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fname: db "LOOPDIR\NOPE.DAT", 0
msg_pass:       db "PASS: LOOPCHN", 13, 10, '$'
msg_fail_found: db "FAIL: LOOPCHN FOUND", 13, 10, '$'
msg_fail_code:  db "FAIL: LOOPCHN CODE", 13, 10, '$'
