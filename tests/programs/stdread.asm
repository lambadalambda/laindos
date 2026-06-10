[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    xor bx, bx
    xor cx, cx
    xor dx, dx
    xor al, al
    mov ah, 0x42
    int 0x21
    jc fail_seek0
    test ax, ax
    jnz fail_seek0
    test dx, dx
    jnz fail_seek0

    mov bx, 1
    mov al, 1
    xor cx, cx
    xor dx, dx
    mov ah, 0x42
    int 0x21
    jc fail_seek1
    mov dx, msg_seek
    mov ah, 0x09
    int 0x21

    mov bx, 5
    xor cx, cx
    xor dx, dx
    xor al, al
    mov ah, 0x42
    int 0x21
    jnc fail_seek5
    cmp ax, 6
    jne fail_seek5
    mov dx, msg_seek5
    mov ah, 0x09
    int 0x21

    cli
    mov ax, 0x0040
    mov es, ax
    mov word [es:0x1A], 0x001E
    mov word [es:0x1C], 0x0020
    mov word [es:0x001E], 0x1E61
    sti

    xor bx, bx
    mov cx, 1
    mov dx, read_buf
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 1
    jne fail_read
    cmp byte [read_buf], 'a'
    jne fail_read
    mov dx, msg_read
    mov ah, 0x09
    int 0x21

    mov bx, 5
    mov cx, 1
    mov dx, read_buf
    mov ah, 0x3F
    int 0x21
    jnc fail_read5
    cmp ax, 6
    jne fail_read5
    mov dx, msg_read5
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

fail_seek0:
    mov dx, msg_fail_seek0
    jmp fail
fail_seek1:
    mov dx, msg_fail_seek1
    jmp fail
fail_seek5:
    mov dx, msg_fail_seek5
    jmp fail
fail_read:
    mov dx, msg_fail_read
    jmp fail
fail_read5:
    mov dx, msg_fail_read5
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

read_buf: db 0
msg_seek:       db "PASS: STDREAD SEEK", 13, 10, '$'
msg_seek5:      db "PASS: STDREAD SEEK5", 13, 10, '$'
msg_read:       db "PASS: STDREAD READ", 13, 10, '$'
msg_read5:      db "PASS: STDREAD READ5", 13, 10, '$'
msg_fail_seek0: db "FAIL: STDREAD SEEK0", 13, 10, '$'
msg_fail_seek1: db "FAIL: STDREAD SEEK1", 13, 10, '$'
msg_fail_seek5: db "FAIL: STDREAD SEEK5", 13, 10, '$'
msg_fail_read:  db "FAIL: STDREAD READ", 13, 10, '$'
msg_fail_read5: db "FAIL: STDREAD READ5", 13, 10, '$'
