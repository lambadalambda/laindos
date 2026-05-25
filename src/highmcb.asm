[bits 16]
[org 0x0100]

%include "src/memory.inc"

start:
    push cs
    pop ds

    mov ah, 0x62
    int 0x21
    mov [psp_seg], bx

    mov ax, MCB_START
    mov es, ax
    cmp byte [es:0], 'M'
    jne fail_first_sig
    cmp word [es:1], 0
    jne fail_first_owner
    cmp word [es:3], 2
    jb fail_first_size

    mov ax, [psp_seg]
    dec ax
    mov es, ax
    cmp byte [es:0], 'Z'
    jne fail_prog_sig
    mov ax, [es:1]
    cmp ax, [psp_seg]
    jne fail_prog_owner

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_first_sig:
    mov dx, fail_first_sig_msg
    jmp fail
fail_first_owner:
    mov dx, fail_first_owner_msg
    jmp fail
fail_first_size:
    mov dx, fail_first_size_msg
    jmp fail
fail_prog_sig:
    mov dx, fail_prog_sig_msg
    jmp fail
fail_prog_owner:
    mov dx, fail_prog_owner_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

psp_seg: dw 0
pass_msg: db "PASS: HIGHMCB", 13, 10, "$"
fail_first_sig_msg: db "FAIL: HIGHMCB FIRST SIG", 13, 10, "$"
fail_first_owner_msg: db "FAIL: HIGHMCB FIRST OWNER", 13, 10, "$"
fail_first_size_msg: db "FAIL: HIGHMCB FIRST SIZE", 13, 10, "$"
fail_prog_sig_msg: db "FAIL: HIGHMCB PROG SIG", 13, 10, "$"
fail_prog_owner_msg: db "FAIL: HIGHMCB PROG OWNER", 13, 10, "$"
