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
    mov si, bx
    add si, 0x22
    cmp word [es:si], 0xFFFF
    jne fail_lol_nul_next
    cmp word [es:si+2], 0xFFFF
    jne fail_lol_nul_next
    cmp word [es:si+4], 0x8004
    jne fail_lol_nul_attr
    add si, 10
    mov di, nul_expected
    mov cx, 8
check_nul_name:
    mov al, [di]
    cmp al, [es:si]
    jne fail_lol_nul_name
    inc si
    inc di
    loop check_nul_name

    push cs
    pop es
    mov si, fcb_path
    mov di, fcb_buf
    mov ax, 0x2901
    int 0x21
    mov [ret_si], si
    cmp al, 0
    jne fail_fcb_ret
    cmp byte [fcb_buf], 1
    jne fail_fcb_drive
    mov si, fcb_buf + 1
    mov di, fcb_expected
    mov cx, 11
    repe cmpsb
    jne fail_fcb_name
    mov si, [ret_si]
    cmp byte [si], ' '
    jne fail_fcb_si

    mov dx, country_buf
    mov ax, 0x3800
    int 0x21
    jc fail_country
    cmp bx, 1
    jne fail_country
    cmp word [country_buf], 0
    jne fail_country
    cmp byte [country_buf+2], '$'
    jne fail_country
    cmp byte [country_buf+9], '.'
    jne fail_country
    cmp byte [country_buf+11], '/'
    jne fail_country
    cmp byte [country_buf+13], ':'
    jne fail_country
    cmp byte [country_buf+22], ','
    jne fail_country
    mov dx, country_buf
    mov ax, 0x3801
    int 0x21
    jc fail_country
    cmp bx, 1
    jne fail_country
    mov ax, 0x38FF
    mov bx, 1
    int 0x21
    jc fail_country

    mov ax, 0x3301
    mov dl, 1
    int 0x21
    jc fail_break
    mov ax, 0x3300
    int 0x21
    jc fail_break
    cmp dl, 1
    jne fail_break
    mov ax, 0x3301
    xor dl, dl
    int 0x21
    jc fail_break
    mov ax, 0x3300
    int 0x21
    jc fail_break
    cmp dl, 0
    jne fail_break
    mov ax, 0x3305
    int 0x21
    jc fail_break
    cmp dl, 1
    jne fail_break
    mov ax, 0x3306
    int 0x21
    jc fail_break
    cmp bl, 5
    jne fail_break
    cmp bh, 0
    jne fail_break
    cmp dx, 0x1000
    jne fail_break

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_lol:
    mov dx, fail_lol_msg
    jmp fail
fail_lol_nul_next:
    mov dx, fail_lol_nul_next_msg
    jmp fail
fail_lol_nul_attr:
    mov dx, fail_lol_nul_attr_msg
    jmp fail
fail_lol_nul_name:
    mov dx, fail_lol_nul_name_msg
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
    jmp fail
fail_country:
    mov dx, fail_country_msg
    jmp fail
fail_break:
    mov dx, fail_break_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fcb_path: db "a:foo.bar rest", 0
ret_si: dw 0
nul_expected: db "NUL     "
fcb_expected: db "FOO     BAR"
fcb_buf: times 16 db 0
country_buf: times 34 db 0
pass_msg: db "PASS: DOSSTRUCT", 13, 10, "$"
fail_lol_msg: db "FAIL: DOSSTRUCT LOL", 13, 10, "$"
fail_lol_nul_next_msg: db "FAIL: DOSSTRUCT LOL NUL NEXT", 13, 10, "$"
fail_lol_nul_attr_msg: db "FAIL: DOSSTRUCT LOL NUL ATTR", 13, 10, "$"
fail_lol_nul_name_msg: db "FAIL: DOSSTRUCT LOL NUL NAME", 13, 10, "$"
fail_fcb_ret_msg: db "FAIL: DOSSTRUCT FCB RET", 13, 10, "$"
fail_fcb_drive_msg: db "FAIL: DOSSTRUCT FCB DRIVE", 13, 10, "$"
fail_fcb_name_msg: db "FAIL: DOSSTRUCT FCB NAME", 13, 10, "$"
fail_fcb_si_msg: db "FAIL: DOSSTRUCT FCB SI", 13, 10, "$"
fail_country_msg: db "FAIL: DOSSTRUCT COUNTRY", 13, 10, "$"
fail_break_msg: db "FAIL: DOSSTRUCT BREAK", 13, 10, "$"
