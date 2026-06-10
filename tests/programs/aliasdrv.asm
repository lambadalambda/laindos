[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x3C
    xor cx, cx
    mov dx, cfile
    int 0x21
    jc fail_create
    mov [master], ax

    mov bx, ax
    mov ah, 0x40
    mov cx, 4
    mov dx, tag_a
    int 0x21
    jc fail_create
    mov bx, [master]
    xor cx, cx
    xor dx, dx
    xor al, al
    mov ah, 0x42
    int 0x21
    jc fail_create

    mov ax, 0x4300
    mov dx, afile
    int 0x21
    jc fail_touch_a

    mov bx, [master]
    mov ah, 0x45
    int 0x21
    jc fail_dup
    mov [alias], ax

    mov bx, 1
    mov cx, [master]
    mov ah, 0x46
    int 0x21
    jc fail_dup

    mov bx, [alias]
    mov ah, 0x40
    mov cx, 4
    mov dx, tag_b
    int 0x21
    jc fail_write
    cmp ax, 4
    jne fail_write
    mov bx, [alias]
    mov ah, 0x3E
    int 0x21
    jc fail_write

    mov ax, 0x3D00
    mov dx, cfile
    int 0x21
    jc fail_verify_c
    mov bx, ax
    mov ah, 0x3F
    mov cx, 4
    mov dx, read_buf
    int 0x21
    jc fail_verify_c
    mov ah, 0x3E
    int 0x21
    mov ax, [read_buf]
    cmp ax, [tag_b]
    jne fail_verify_c
    mov ax, [read_buf+2]
    cmp ax, [tag_b+2]
    jne fail_verify_c
    mov dx, msg_cfile
    mov ah, 0x09
    int 0x21

    mov ax, 0x3D00
    mov dx, afile
    int 0x21
    jc fail_verify_a
    mov bx, ax
    mov ah, 0x3F
    mov cx, 7
    mov dx, read_buf
    int 0x21
    jc fail_verify_a
    cmp ax, 7
    jne fail_verify_a
    mov ah, 0x3E
    int 0x21
    mov si, read_buf
    mov di, aonly_tag
    mov cx, 7
    repe cmpsb
    jne fail_verify_a
    mov dx, msg_afile
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_create:
    mov dx, msg_fail_create
    jmp fail
fail_touch_a:
    mov dx, msg_fail_touch
    jmp fail
fail_dup:
    mov dx, msg_fail_dup
    jmp fail
fail_write:
    mov dx, msg_fail_write
    jmp fail
fail_verify_c:
    mov dx, msg_fail_cfile
    jmp fail
fail_verify_a:
    push cs
    pop ds
    mov dx, msg_fail_afile
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

master: dw 0
alias:  dw 0
cfile: db "C:ALIAS.DAT", 0
afile: db "A:AONLY.TXT", 0
tag_a: db "AAAA"
tag_b: db "BBBB"
aonly_tag: db "DRIVEOK"
read_buf: times 8 db 0
msg_cfile:      db "PASS: ALIASDRV CFILE", 13, 10, '$'
msg_afile:      db "PASS: ALIASDRV AFILE", 13, 10, '$'
msg_fail_create: db "FAIL: ALIASDRV CREATE", 13, 10, '$'
msg_fail_touch:  db "FAIL: ALIASDRV TOUCH", 13, 10, '$'
msg_fail_dup:    db "FAIL: ALIASDRV DUP", 13, 10, '$'
msg_fail_write:  db "FAIL: ALIASDRV WRITE", 13, 10, '$'
msg_fail_cfile:  db "FAIL: ALIASDRV CFILE", 13, 10, '$'
msg_fail_afile:  db "FAIL: ALIASDRV AFILE", 13, 10, '$'
