[bits 16]
[org 0x0100]

TAIL_LEN equ 8

start:
    push cs
    pop ds
    push cs
    pop es
    cld

    mov ah, 0x62
    int 0x21
    mov [psp_seg], bx
    mov es, bx
    mov ax, [es:0x2C]
    test ax, ax
    jz fail_env
    mov es, ax
    mov si, comspec_var
    call find_var
    jc fail_env

    mov es, [psp_seg]
    cmp byte [es:0x80], 0
    je check_empty
    cmp byte [es:0x80], TAIL_LEN
    jne fail_tail
    push cs
    pop ds
    mov si, expected_tail
    mov di, 0x81
    mov cx, TAIL_LEN
    repe cmpsb
    jne fail_tail
    push cs
    pop ds
    mov si, fcb1_expected
    mov di, 0x5C
    mov cx, 16
    repe cmpsb
    jne fail_fcb1
    push cs
    pop ds
    mov si, fcb2_expected
    mov di, 0x6C
    mov cx, 16
    repe cmpsb
    jne fail_fcb2
    jmp pass

check_empty:
    cmp byte [es:0x81], 0x0D
    jne fail_tail
    xor di, di
    mov cx, 16
.empty_fcb1:
    cmp byte [es:0x5C+di], 0
    jne fail_fcb1
    inc di
    loop .empty_fcb1
    xor di, di
    mov cx, 16
.empty_fcb2:
    cmp byte [es:0x6C+di], 0
    jne fail_fcb2
    inc di
    loop .empty_fcb2

pass:
    push cs
    pop ds
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C25
    int 0x21

find_var:
    push ax
    push bx
    push dx
    push si
    mov dx, si
    xor bx, bx
.next_string:
    cmp byte [es:bx], 0
    je .not_found
    mov si, dx
    mov di, bx
.compare:
    lodsb
    test al, al
    jz .found
    cmp al, [es:di]
    jne .skip_string
    inc di
    jmp .compare
.skip_string:
    mov di, bx
.skip_loop:
    cmp byte [es:di], 0
    je .skipped
    inc di
    jmp .skip_loop
.skipped:
    lea bx, [di+1]
    jmp .next_string
.found:
    pop si
    pop dx
    pop bx
    pop ax
    clc
    ret
.not_found:
    pop si
    pop dx
    pop bx
    pop ax
    stc
    ret

fail_env:
    push cs
    pop ds
    mov dx, fail_env_msg
    jmp fail
fail_tail:
    push cs
    pop ds
    mov dx, fail_tail_msg
    jmp fail
fail_fcb1:
    push cs
    pop ds
    mov dx, fail_fcb1_msg
    jmp fail
fail_fcb2:
    push cs
    pop ds
    mov dx, fail_fcb2_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

psp_seg: dw 0
comspec_var: db "COMSPEC=", 0
expected_tail: db " /EDGE42"
fcb1_expected: db 1, "FIRST   TXT", 0x11, 0x22, 0x33, 0x44
fcb2_expected: db 2, "SECOND  BIN", 0x55, 0x66, 0x77, 0x88
pass_msg: db "PASS: EXECPCHK", 13, 10, "$"
fail_env_msg: db "FAIL: EXECPCHK ENV", 13, 10, "$"
fail_tail_msg: db "FAIL: EXECPCHK TAIL", 13, 10, "$"
fail_fcb1_msg: db "FAIL: EXECPCHK FCB1", 13, 10, "$"
fail_fcb2_msg: db "FAIL: EXECPCHK FCB2", 13, 10, "$"
