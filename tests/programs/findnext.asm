[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    cld

    mov dx, dta_all
    mov ah, 0x1A
    int 0x21

    mov dx, all_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find_all
    mov si, expected_kernel
    mov di, dta_all + 30
    call check_name
    jc fail_find_all

    mov ah, 0x4F
    int 0x21
    jc fail_next_all
    mov si, expected_program
    mov di, dta_all + 30
    call check_name
    jc fail_next_all

    mov dx, dta_txt
    mov ah, 0x1A
    int 0x21

    mov dx, txt_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find_txt
    mov si, expected_a
    mov di, dta_txt + 30
    call check_name
    jc fail_find_txt

    mov dx, dta_com
    mov ah, 0x1A
    int 0x21

    mov dx, zcom_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_find_com
    mov si, expected_z
    mov di, dta_com + 30
    call check_name
    jc fail_find_com

    mov dx, dta_txt
    mov ah, 0x1A
    int 0x21

    mov ah, 0x4F
    int 0x21
    jc fail_next_txt
    mov si, expected_b
    mov di, dta_txt + 30
    call check_name
    jc fail_next_txt

    mov ah, 0x4F
    int 0x21
    jc fail_next_txt
    mov si, expected_aa
    mov di, dta_txt + 30
    call check_name
    jc fail_next_txt

    mov ah, 0x4F
    int 0x21
    jnc fail_next_exhaust

    mov dx, dta_qtxt
    mov ah, 0x1A
    int 0x21

    mov dx, qtxt_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_qtxt
    mov si, expected_a
    mov di, dta_qtxt + 30
    call check_name
    jc fail_qtxt

    mov ah, 0x4F
    int 0x21
    jc fail_qtxt
    mov si, expected_b
    mov di, dta_qtxt + 30
    call check_name
    jc fail_qtxt

    mov ah, 0x4F
    int 0x21
    jnc fail_qtxt_exhaust

    mov dx, dta_aqtxt
    mov ah, 0x1A
    int 0x21

    mov dx, aqtxt_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_aqtxt
    mov si, expected_a
    mov di, dta_aqtxt + 30
    call check_name
    jc fail_aqtxt

    mov ah, 0x4F
    int 0x21
    jc fail_aqtxt
    mov si, expected_aa
    mov di, dta_aqtxt + 30
    call check_name
    jc fail_aqtxt

    mov ah, 0x4F
    int 0x21
    jnc fail_aqtxt_exhaust

    mov dx, dta_noext
    mov ah, 0x1A
    int 0x21

    mov dx, noext_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_noext
    mov si, expected_noext
    mov di, dta_noext + 30
    call check_name
    jc fail_noext

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

check_name:
    lodsb
    cmp al, [di]
    jne .bad
    inc di
    test al, al
    jnz check_name
    clc
    ret
.bad:
    stc
    ret

fail_find_txt:
    mov dx, fail_find_txt_msg
    jmp fail
fail_find_com:
    mov dx, fail_find_com_msg
    jmp fail
fail_next_txt:
    mov dx, fail_next_txt_msg
    jmp fail
fail_find_all:
    mov dx, fail_find_all_msg
    jmp fail
fail_next_all:
    mov dx, fail_next_all_msg
    jmp fail
fail_next_exhaust:
    mov dx, fail_next_exhaust_msg
    jmp fail
fail_qtxt:
    mov dx, fail_qtxt_msg
    jmp fail
fail_qtxt_exhaust:
    mov dx, fail_qtxt_exhaust_msg
    jmp fail
fail_aqtxt:
    mov dx, fail_aqtxt_msg
    jmp fail
fail_aqtxt_exhaust:
    mov dx, fail_aqtxt_exhaust_msg
    jmp fail
fail_noext:
    mov dx, fail_noext_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

txt_pattern: db "*.TXT", 0
zcom_pattern: db "Z*.COM", 0
all_pattern: db "*.*", 0
qtxt_pattern: db "?.TXT", 0
aqtxt_pattern: db "A?.TXT", 0
noext_pattern: db "NOEXT.*", 0
expected_kernel: db "KERNEL.SYS", 0
expected_program: db "FINDNEXT.COM", 0
expected_a: db "A.TXT", 0
expected_b: db "B.TXT", 0
expected_aa: db "AA.TXT", 0
expected_z: db "Z.COM", 0
expected_noext: db "NOEXT", 0
pass_msg: db "PASS: FINDNEXT", 13, 10, "$"
fail_find_txt_msg: db "FAIL: FINDNEXT FIRST TXT", 13, 10, "$"
fail_find_com_msg: db "FAIL: FINDNEXT COM", 13, 10, "$"
fail_next_txt_msg: db "FAIL: FINDNEXT NEXT TXT", 13, 10, "$"
fail_find_all_msg: db "FAIL: FINDNEXT FIND ALL", 13, 10, "$"
fail_next_all_msg: db "FAIL: FINDNEXT NEXT ALL", 13, 10, "$"
fail_next_exhaust_msg: db "FAIL: FINDNEXT TXT EXHAUST", 13, 10, "$"
fail_qtxt_msg: db "FAIL: FINDNEXT QTXT", 13, 10, "$"
fail_qtxt_exhaust_msg: db "FAIL: FINDNEXT QTXT EXHAUST", 13, 10, "$"
fail_aqtxt_msg: db "FAIL: FINDNEXT AQTXT", 13, 10, "$"
fail_aqtxt_exhaust_msg: db "FAIL: FINDNEXT AQTXT EXHAUST", 13, 10, "$"
fail_noext_msg: db "FAIL: FINDNEXT NOEXT", 13, 10, "$"
dta_all: times 64 db 0
dta_txt: times 64 db 0
dta_com: times 64 db 0
dta_qtxt: times 64 db 0
dta_aqtxt: times 64 db 0
dta_noext: times 64 db 0
