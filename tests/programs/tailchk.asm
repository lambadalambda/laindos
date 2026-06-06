[bits 16]
[org 0x0100]

MAX_SAFE_TAIL equ 126

start:
    mov ah, 0x62
    int 0x21
    mov es, bx
    mov al, [es:0x80]
    test al, al
    jz check_empty
    cmp al, MAX_SAFE_TAIL
    je check_long
    jmp fail_len

check_empty:
    cmp byte [es:0x81], 0x0D
    jne fail_cr
    cmp byte [es:0x82], 0
    jne fail_leak
    jmp pass

check_long:
    cmp byte [es:0x81], 'A'
    jne fail_data
    cmp byte [es:0x82], 'B'
    jne fail_data
    cmp byte [es:0xFE], 'V'
    jne fail_data
    cmp byte [es:0xFF], 0x0D
    jne fail_cr
    jmp pass

pass:
    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C33
    int 0x21

fail_len:
    push cs
    pop ds
    mov dx, fail_len_msg
    jmp fail
fail_cr:
    push cs
    pop ds
    mov dx, fail_cr_msg
    jmp fail
fail_leak:
    push cs
    pop ds
    mov dx, fail_leak_msg
    jmp fail
fail_data:
    push cs
    pop ds
    mov dx, fail_data_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db "PASS: TAILCHK", 13, 10, "$"
fail_len_msg: db "FAIL: TAILCHK LEN", 13, 10, "$"
fail_cr_msg: db "FAIL: TAILCHK CR", 13, 10, "$"
fail_leak_msg: db "FAIL: TAILCHK LEAK", 13, 10, "$"
fail_data_msg: db "FAIL: TAILCHK DATA", 13, 10, "$"
