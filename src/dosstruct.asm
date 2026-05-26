[bits 16]
[org 0x0100]

%include "src/memory.inc"

start:
    push cs
    pop ds

    mov ah, 0x52
    int 0x21
    cmp word [es:bx-2], MCB_START
    jne fail_lol

    push cs
    pop es
    mov si, fcb_path
    mov di, fcb_buf
    mov ax, 0x2901
    int 0x21
    mov [ret_si], si
    cmp al, 0
    jne fail_fcb_ret
    cmp byte [fcb_buf], 3
    jne fail_fcb_drive
    mov si, fcb_buf + 1
    mov di, fcb_expected
    mov cx, 11
    repe cmpsb
    jne fail_fcb_name
    mov si, [ret_si]
    cmp byte [si], ' '
    jne fail_fcb_si

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_lol:
    mov dx, fail_lol_msg
    jmp fail
fail_fcb_ret:
    mov dx, fail_fcb_ret_msg
    jmp fail
fail_fcb_drive:
    mov dx, fail_fcb_drive_msg
    jmp fail
fail_fcb_name:
    mov dx, fail_fcb_name_msg
    jmp fail
fail_fcb_si:
    mov dx, fail_fcb_si_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fcb_path: db "c:foo.bar rest", 0
ret_si: dw 0
fcb_expected: db "FOO     BAR"
fcb_buf: times 16 db 0
pass_msg: db "PASS: DOSSTRUCT", 13, 10, "$"
fail_lol_msg: db "FAIL: DOSSTRUCT LOL", 13, 10, "$"
fail_fcb_ret_msg: db "FAIL: DOSSTRUCT FCB RET", 13, 10, "$"
fail_fcb_drive_msg: db "FAIL: DOSSTRUCT FCB DRIVE", 13, 10, "$"
fail_fcb_name_msg: db "FAIL: DOSSTRUCT FCB NAME", 13, 10, "$"
fail_fcb_si_msg: db "FAIL: DOSSTRUCT FCB SI", 13, 10, "$"
