[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x34
    int 0x21
    jc fail_pointer
    mov [indos_seg], es
    mov [indos_off], bx
    mov al, byte [es:bx]
    mov [before_flag], al
    test al, al
    jnz fail_before

    mov dx, msg
    mov ah, 0x09
    int 0x21
    jc fail_dos

    mov es, [indos_seg]
    mov bx, [indos_off]
    mov al, byte [es:bx]
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
fail_pointer:
    push cs
    pop ds
    mov dx, fail_pointer_msg
    jmp fail
fail_dos:
    push cs
    pop ds
    mov dx, fail_dos_msg
    jmp fail
fail_after:
    push cs
    pop ds
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
indos_seg: dw 0
indos_off: dw 0
msg: db "OK", 13, 10, "$"
pass_msg: db "PASS: INDOS", 13, 10, "$"
fail_pointer_msg: db "FAIL: INDOS POINTER", 13, 10, "$"
fail_before_msg: db "FAIL: INDOS BEFORE", 13, 10, "$"
fail_dos_msg: db "FAIL: INDOS DOS", 13, 10, "$"
fail_after_msg: db "FAIL: INDOS AFTER", 13, 10, "$"
