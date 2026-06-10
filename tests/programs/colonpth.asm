[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x3C
    xor cx, cx
    mov dx, adjacent
    int 0x21
    jc fail_setup
    mov bx, ax
    mov ah, 0x3E
    int 0x21

    mov ax, 0x3D00
    mov dx, colon_path
    int 0x21
    jnc fail_colon
    mov dx, msg_colon
    mov ah, 0x09
    int 0x21

    mov ax, 0x3D00
    mov dx, trail_path
    int 0x21
    jnc fail_trail
    mov dx, msg_trail
    mov ah, 0x09
    int 0x21

    mov ax, 0x3D00
    mov dx, adjacent
    int 0x21
    jc fail_valid
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    mov dx, msg_valid
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_colon:
    mov dx, msg_fail_colon
    jmp fail
fail_trail:
    mov dx, msg_fail_trail
    jmp fail
fail_valid:
    mov dx, msg_fail_valid
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

colon_path: db ':', 0
adjacent:   db "ADJACENT.DAT", 0
trail_path: db "FOO\:", 0
adjacent2:  db "ADJACENT.DAT", 0
msg_colon:      db "PASS: COLONPTH BARE", 13, 10, '$'
msg_trail:      db "PASS: COLONPTH TRAIL", 13, 10, '$'
msg_valid:      db "PASS: COLONPTH VALID", 13, 10, '$'
msg_fail_setup: db "FAIL: COLONPTH SETUP", 13, 10, '$'
msg_fail_colon: db "FAIL: COLONPTH BARE", 13, 10, '$'
msg_fail_trail: db "FAIL: COLONPTH TRAIL", 13, 10, '$'
msg_fail_valid: db "FAIL: COLONPTH VALID", 13, 10, '$'
