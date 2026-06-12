[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    push cs
    pop es
    ; DOS-style prologue: move the stack inside the kept region, then
    ; shrink the block so later allocations/execs have memory to use
    mov sp, 0x1FFE
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21

    mov [exec_params+4], ds
    mov bx, exec_params
    mov dx, child_path
    mov ax, 0x4B00
    int 0x21
    jc fail_exec
    mov ah, 0x4D
    int 0x21
    test ax, ax
    jnz fail_retcode
    mov dx, msg_retcode
    mov ah, 0x09
    int 0x21

    mov dl, 2
    mov ah, 0x0E
    int 0x21
    mov ax, 0x3305
    int 0x21
    cmp dl, 1
    jne fail_boot
    xor dl, dl
    mov ah, 0x0E
    int 0x21
    mov dx, msg_boot
    mov ah, 0x09
    int 0x21

    mov si, bad_drive_path
    mov di, fcb
    mov ax, 0x2900
    int 0x21
    cmp al, 0xFF
    jne fail_parse
    mov si, good_drive_path
    mov di, fcb
    mov ax, 0x2900
    int 0x21
    cmp al, 0xFF
    je fail_parse
    mov dx, msg_parse
    mov ah, 0x09
    int 0x21

    mov ax, 0x1680
    int 0x2F
    cmp al, 0x80
    jne fail_int2f
    mov dx, msg_int2f
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_exec:
    mov dx, msg_fail_exec
    jmp fail
fail_retcode:
    mov dx, msg_fail_retcode
    jmp fail
fail_boot:
    mov dx, msg_fail_boot
    jmp fail
fail_parse:
    mov dx, msg_fail_parse
    jmp fail
fail_int2f:
    mov dx, msg_fail_int2f
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

child_path: db "AH0CHILD.COM", 0
bad_drive_path:  db "Z:FOO.TXT", 0
good_drive_path: db "C:FOO.TXT", 0
fcb: times 40 db 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
msg_retcode:      db "PASS: MISC21 RETCODE", 13, 10, '$'
msg_boot:         db "PASS: MISC21 BOOT", 13, 10, '$'
msg_parse:        db "PASS: MISC21 PARSE", 13, 10, '$'
msg_int2f:        db "PASS: MISC21 INT2F", 13, 10, '$'
msg_fail_exec:    db "FAIL: MISC21 EXEC", 13, 10, '$'
msg_fail_retcode: db "FAIL: MISC21 RETCODE", 13, 10, '$'
msg_fail_boot:    db "FAIL: MISC21 BOOT", 13, 10, '$'
msg_fail_parse:   db "FAIL: MISC21 PARSE", 13, 10, '$'
msg_fail_int2f:   db "FAIL: MISC21 INT2F", 13, 10, '$'
