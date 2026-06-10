[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov si, keys_simple
    mov cx, 3
    call stuff_keys
    xor bx, bx
    mov cx, 64
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc fail_simple
    cmp ax, 4
    jne fail_simple
    cmp word [buf], 'hi'
    jne fail_simple
    cmp word [buf+2], 0x0A0D
    jne fail_simple
    mov dx, msg_simple
    mov ah, 0x09
    int 0x21

    mov si, keys_bs
    mov cx, 5
    call stuff_keys
    xor bx, bx
    mov cx, 64
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc fail_bs
    cmp ax, 4
    jne fail_bs
    cmp word [buf], 'ac'
    jne fail_bs
    mov dx, msg_bs
    mov ah, 0x09
    int 0x21

    mov si, keys_ext
    mov cx, 3
    call stuff_keys
    xor bx, bx
    mov cx, 64
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc fail_ext
    cmp ax, 3
    jne fail_ext
    cmp byte [buf], 'x'
    jne fail_ext
    mov dx, msg_ext
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

stuff_keys:
    push ax
    push bx
    push cx
    push si
    push es
    cli
    mov ax, 0x0040
    mov es, ax
    mov bx, 0x001E
    mov word [es:0x1A], 0x001E
.stuff_loop:
    lodsw
    mov [es:bx], ax
    add bx, 2
    loop .stuff_loop
    mov [es:0x1C], bx
    sti
    pop es
    pop si
    pop cx
    pop bx
    pop ax
    ret

fail_simple:
    mov dx, msg_fail_simple
    jmp fail
fail_bs:
    mov dx, msg_fail_bs
    jmp fail
fail_ext:
    mov dx, msg_fail_ext
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

keys_simple: dw 0x2368, 0x1769, 0x1C0D
keys_bs:     dw 0x1E61, 0x3062, 0x0E08, 0x2E63, 0x1C0D
keys_ext:    dw 0x3B00, 0x2D78, 0x1C0D
buf: times 66 db 0
msg_simple:      db "PASS: CONREAD LINE", 13, 10, '$'
msg_bs:          db "PASS: CONREAD BS", 13, 10, '$'
msg_ext:         db "PASS: CONREAD EXT", 13, 10, '$'
msg_fail_simple: db "FAIL: CONREAD LINE", 13, 10, '$'
msg_fail_bs:     db "FAIL: CONREAD BS", 13, 10, '$'
msg_fail_ext:    db "FAIL: CONREAD EXT", 13, 10, '$'
