[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, dta_buf
    mov ah, 0x1A
    int 0x21

    mov dx, dir_name
    mov ah, 0x39
    int 0x21
    jc fail_dir

    mov dx, fcb_missing
    mov ah, 0x11
    int 0x21
    cmp al, 0xFF
    jne fail_missing

    mov dx, fcb_exact
    mov ah, 0x11
    int 0x21
    cmp al, 0
    jne fail_find
    cmp byte [dta_buf], 1
    jne fail_find
    mov si, expected_name
    mov di, dta_buf+1
    mov cx, 11
    repe cmpsb
    jne fail_find
    cmp byte [dta_buf+12], 0x20
    jne fail_find

    mov dx, fcb_exact
    mov ah, 0x12
    int 0x21
    cmp al, 0xFF
    jne fail_next

    mov dx, fcb_wild
    mov ah, 0x11
    int 0x21
    cmp al, 0
    jne fail_find

    mov dx, fcb_dir_normal
    mov ah, 0x11
    int 0x21
    cmp al, 0xFF
    jne fail_attr

    mov dx, fcb_dir_extended
    mov ah, 0x11
    int 0x21
    cmp al, 0
    jne fail_attr
    mov si, expected_dir_name
    mov di, dta_buf+1
    mov cx, 11
    repe cmpsb
    jne fail_attr
    cmp byte [dta_buf+12], 0x10
    jne fail_attr

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_missing:
    mov dx, fail_missing_msg
    jmp fail
fail_find:
    mov dx, fail_find_msg
    jmp fail
fail_next:
    mov dx, fail_next_msg
    jmp fail
fail_dir:
    mov dx, fail_dir_msg
    jmp fail
fail_attr:
    mov dx, fail_attr_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fcb_missing: db 0, "MISSING ", "TXT"
    times 25 db 0
fcb_exact: db 0, "FCBFILE ", "TXT"
    times 25 db 0
fcb_wild: db 0, "FCB?????", "TXT"
    times 25 db 0
fcb_dir_normal: db 0, "FCBDIR  ", "   "
    times 25 db 0
fcb_dir_extended: db 0xFF
    times 5 db 0
    db 0x10
    db 0, "FCBDIR  ", "   "
    times 25 db 0
expected_name: db "FCBFILE TXT"
expected_dir_name: db "FCBDIR     "
dir_name: db "FCBDIR", 0
dta_buf: times 64 db 0
pass_msg: db "PASS: FCBFIND", 13, 10, "$"
fail_missing_msg: db "FAIL: FCBFIND MISSING", 13, 10, "$"
fail_find_msg: db "FAIL: FCBFIND FIND", 13, 10, "$"
fail_next_msg: db "FAIL: FCBFIND NEXT", 13, 10, "$"
fail_dir_msg: db "FAIL: FCBFIND DIR", 13, 10, "$"
fail_attr_msg: db "FAIL: FCBFIND ATTR", 13, 10, "$"
