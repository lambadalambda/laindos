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
    call scan_pattern
    test byte [seen_a_txt], 1
    jz fail_all
    test byte [seen_b], 1
    jz fail_all
    test byte [seen_c_exe], 1
    jz fail_all

    call clear_seen
    mov dx, dta_all
    mov ah, 0x1A
    int 0x21
    mov dx, bstar_pattern
    call scan_pattern
    test byte [seen_b], 1
    jz fail_bstar
    test byte [seen_b_exe], 1
    jz fail_bstar
    test byte [seen_a_txt], 1
    jnz fail_bstar
    test byte [seen_c_exe], 1
    jnz fail_bstar

    call clear_seen
    mov dx, dta_all
    mov ah, 0x1A
    int 0x21
    mov dx, exe_pattern
    call scan_pattern
    test byte [seen_b_exe], 1
    jz fail_exe
    test byte [seen_c_exe], 1
    jz fail_exe
    test byte [seen_a_txt], 1
    jnz fail_exe
    test byte [seen_b], 1
    jnz fail_exe

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

scan_pattern:
    mov si, seen_a_txt
    mov cx, 4
.clear:
    mov byte [si], 0
    inc si
    loop .clear
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc .done
.match:
    call mark_seen
    mov ah, 0x4F
    int 0x21
    jnc .match
.done:
    ret

clear_seen:
    mov si, seen_a_txt
    mov cx, 4
.loop:
    mov byte [si], 0
    inc si
    loop .loop
    ret

mark_seen:
    mov si, expected_a_txt
    mov di, dta_all + 30
    call name_eq
    jnc .a_txt
    mov si, expected_b
    mov di, dta_all + 30
    call name_eq
    jnc .b
    mov si, expected_b_exe
    mov di, dta_all + 30
    call name_eq
    jnc .b_exe
    mov si, expected_c_exe
    mov di, dta_all + 30
    call name_eq
    jnc .c_exe
    ret
.a_txt:
    mov byte [seen_a_txt], 1
    ret
.b:
    mov byte [seen_b], 1
    ret
.b_exe:
    mov byte [seen_b_exe], 1
    ret
.c_exe:
    mov byte [seen_c_exe], 1
    ret

name_eq:
    lodsb
    cmp al, [di]
    jne .bad
    inc di
    test al, al
    jnz name_eq
    clc
    ret
.bad:
    stc
    ret

fail_all:
    mov dx, fail_all_msg
    jmp fail
fail_bstar:
    mov dx, fail_bstar_msg
    jmp fail
fail_exe:
    mov dx, fail_exe_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

all_pattern: db "*", 0
bstar_pattern: db "B*", 0
exe_pattern: db "*.EXE", 0
expected_a_txt: db "A.TXT", 0
expected_b: db "B", 0
expected_b_exe: db "B.EXE", 0
expected_c_exe: db "C.EXE", 0
seen_a_txt: db 0
seen_b: db 0
seen_b_exe: db 0
seen_c_exe: db 0
pass_msg: db "PASS: FINDSTAR", 13, 10, "$"
fail_all_msg: db "FAIL: FINDSTAR ALL", 13, 10, "$"
fail_bstar_msg: db "FAIL: FINDSTAR BSTAR", 13, 10, "$"
fail_exe_msg: db "FAIL: FINDSTAR EXE", 13, 10, "$"
dta_all: times 64 db 0
