[bits 16]
[org 0x0100]

%define KERNEL_SEG 0x0340
%define INDOS_OFFSET 0x7878

start:
    push cs
    pop ds

    mov ax, KERNEL_SEG
    mov es, ax
    mov al, byte [es:INDOS_OFFSET]
    mov [before_flag], al
    test al, al
    jnz fail_before

    mov dx, msg
    mov ah, 0x09
    int 0x21
    jc fail_dos

    mov ax, KERNEL_SEG
    mov es, ax
    mov al, byte [es:INDOS_OFFSET]
    test al, al
    jnz fail_after

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_before:
    mov dx, fail_before_msg
    jmp fail
fail_dos:
    mov dx, fail_dos_msg
    jmp fail
fail_after:
    mov dx, fail_after_msg
    jmp fail

fail:
    push ds
    pop es
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

before_flag: db 0
msg: db "OK", 13, 10, "$"
pass_msg: db "PASS: INDOS", 13, 10, "$"
fail_before_msg: db "FAIL: INDOS BEFORE", 13, 10, "$"
fail_dos_msg: db "FAIL: INDOS DOS", 13, 10, "$"
fail_after_msg: db "FAIL: INDOS AFTER", 13, 10, "$"
