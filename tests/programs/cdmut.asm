[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x41
    mov dx, cd_missing
    int 0x21
    jnc fail_del
    cmp ax, 5
    jne fail_del
    mov ah, 0x41
    mov dx, cd_hello
    int 0x21
    jnc fail_del
    cmp ax, 5
    jne fail_del
    mov dx, msg_del
    mov ah, 0x09
    int 0x21

    mov ah, 0x56
    mov dx, cd_hello
    mov di, cd_target
    push ds
    pop es
    int 0x21
    jnc fail_ren
    cmp ax, 5
    jne fail_ren
    mov dx, msg_ren
    mov ah, 0x09
    int 0x21

    mov ah, 0x39
    mov dx, cd_newdir
    int 0x21
    jnc fail_md
    cmp ax, 5
    jne fail_md
    mov dx, msg_md
    mov ah, 0x09
    int 0x21

    mov ah, 0x3A
    mov dx, cd_newdir
    int 0x21
    jnc fail_rd
    cmp ax, 5
    jne fail_rd
    mov dx, msg_rd
    mov ah, 0x09
    int 0x21

    mov ax, 0x3D00
    mov dx, cd_hello
    int 0x21
    jc fail_read
    mov bx, ax
    mov ah, 0x3F
    mov cx, 5
    mov dx, read_buf
    int 0x21
    jc fail_read
    cmp ax, 5
    jne fail_read
    mov ah, 0x3E
    int 0x21
    cmp word [read_buf], 'He'
    jne fail_read
    mov dx, msg_read
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_del:
    mov dx, msg_fail_del
    jmp fail
fail_ren:
    mov dx, msg_fail_ren
    jmp fail
fail_md:
    mov dx, msg_fail_md
    jmp fail
fail_rd:
    mov dx, msg_fail_rd
    jmp fail
fail_read:
    mov dx, msg_fail_read
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

cd_missing: db "D:NOPE.TXT", 0
cd_hello:   db "D:HELLO.TXT", 0
cd_target:  db "D:OTHER.TXT", 0
cd_newdir:  db "D:NEWDIR", 0
read_buf: times 6 db 0
msg_del:       db "PASS: CDMUT DEL", 13, 10, '$'
msg_ren:       db "PASS: CDMUT REN", 13, 10, '$'
msg_md:        db "PASS: CDMUT MD", 13, 10, '$'
msg_rd:        db "PASS: CDMUT RD", 13, 10, '$'
msg_read:      db "PASS: CDMUT READ", 13, 10, '$'
msg_fail_del:  db "FAIL: CDMUT DEL", 13, 10, '$'
msg_fail_ren:  db "FAIL: CDMUT REN", 13, 10, '$'
msg_fail_md:   db "FAIL: CDMUT MD", 13, 10, '$'
msg_fail_rd:   db "FAIL: CDMUT RD", 13, 10, '$'
msg_fail_read: db "FAIL: CDMUT READ", 13, 10, '$'
