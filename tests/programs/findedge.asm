[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    cld

    mov dx, dta_empty
    mov ah, 0x1A
    int 0x21

    mov ah, 0x4F
    int 0x21
    jnc fail_next_empty
    cmp ax, 2
    jne fail_next_empty

    mov dx, no_match_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jnc fail_no_match
    cmp ax, 2
    jne fail_no_match

    mov dx, bad_path_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jnc fail_bad_path
    cmp ax, 3
    jne fail_bad_path

    mov dx, bad_drive_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jnc fail_bad_drive
    cmp ax, 15
    jne fail_bad_drive

    mov dx, dta_root
    mov ah, 0x1A
    int 0x21

    mov dx, drive_root_pattern
    xor cx, cx
    mov ah, 0x4E
    int 0x21
    jc fail_drive_root
    mov si, expected_com
    mov di, dta_root + 30
    call check_name
    jc fail_drive_root

    mov ah, 0x4F
    int 0x21
    jnc fail_next_exhaust
    cmp ax, 2
    jne fail_next_exhaust

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

fail_next_empty:
    mov dx, fail_next_empty_msg
    jmp fail
fail_no_match:
    mov dx, fail_no_match_msg
    jmp fail
fail_bad_path:
    mov dx, fail_bad_path_msg
    jmp fail
fail_bad_drive:
    mov dx, fail_bad_drive_msg
    jmp fail
fail_drive_root:
    mov dx, fail_drive_root_msg
    jmp fail
fail_next_exhaust:
    mov dx, fail_next_exhaust_msg

fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

no_match_pattern: db "NOMATCH.XYZ", 0
bad_path_pattern: db "NOSUCH\*.COM", 0
bad_drive_pattern: db "Z:\*.COM", 0
drive_root_pattern: db "A:\*.COM", 0
expected_com: db "FINDEDGE.COM", 0
pass_msg: db "PASS: FINDEDGE", 13, 10, "$"
fail_next_empty_msg: db "FAIL: FINDEDGE NEXT EMPTY", 13, 10, "$"
fail_no_match_msg: db "FAIL: FINDEDGE NO MATCH", 13, 10, "$"
fail_bad_path_msg: db "FAIL: FINDEDGE BAD PATH", 13, 10, "$"
fail_bad_drive_msg: db "FAIL: FINDEDGE BAD DRIVE", 13, 10, "$"
fail_drive_root_msg: db "FAIL: FINDEDGE DRIVE ROOT", 13, 10, "$"
fail_next_exhaust_msg: db "FAIL: FINDEDGE NEXT EXHAUST", 13, 10, "$"
dta_empty: times 64 db 0
dta_root: times 64 db 0
