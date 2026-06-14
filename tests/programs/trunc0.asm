[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x36
    xor dl, dl
    int 0x21
    cmp ax, 0xFFFF
    je fail_setup
    mov [free_before], bx

    mov ah, 0x3C
    xor cx, cx
    mov dx, fname
    int 0x21
    jc fail_setup
    mov [handle], ax
    mov bx, ax
    mov cx, 4
.fill:
    push cx
    mov ah, 0x40
    mov cx, 512
    mov dx, buf512
    int 0x21
    pop cx
    jc fail_setup
    loop .fill
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21

    mov ax, 0x3D02
    mov dx, fname
    int 0x21
    jc fail_setup
    mov [handle], ax

    mov bx, [handle]
    mov cx, 0
    mov dx, 100
    xor al, al
    mov ah, 0x42
    int 0x21
    jc fail_setup
    mov bx, [handle]
    mov ah, 0x40
    xor cx, cx
    int 0x21
    jc fail_trunc

    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov al, 2
    mov ah, 0x42
    int 0x21
    jc fail_trunc
    cmp ax, 100
    jne fail_size
    test dx, dx
    jnz fail_size
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    mov dx, msg_size
    mov ah, 0x09
    int 0x21

    mov ax, 0x3D00
    mov dx, fname
    int 0x21
    jc fail_persist
    mov bx, ax
    xor cx, cx
    xor dx, dx
    mov al, 2
    mov ah, 0x42
    int 0x21
    jc fail_persist
    cmp ax, 100
    jne fail_persist
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    mov dx, msg_persist
    mov ah, 0x09
    int 0x21

    mov ah, 0x36
    xor dl, dl
    int 0x21
    cmp ax, 0xFFFF
    je fail_free
    mov dx, [free_before]
    dec dx
    cmp bx, dx
    jne fail_free
    mov dx, msg_free
    mov ah, 0x09
    int 0x21

    call stale_cache_probe
    mov dx, msg_cache
    mov ah, 0x09
    int 0x21

    mov ax, 0x4C00
    int 0x21

stale_cache_probe:
    mov ah, 0x3C
    xor cx, cx
    mov dx, fname_cache
    int 0x21
    jc fail_cache
    mov [h_cache_a], ax
    mov bx, ax
    mov cx, 4
.fill_cache_file:
    push cx
    mov ah, 0x40
    mov cx, 512
    mov dx, buf512
    int 0x21
    pop cx
    jc fail_cache
    cmp ax, 512
    jne fail_cache
    loop .fill_cache_file
    mov bx, [h_cache_a]
    mov ah, 0x3E
    int 0x21
    jc fail_cache

    mov ax, 0x3D00
    mov dx, fname_cache
    int 0x21
    jc fail_cache
    mov [h_cache_a], ax
    mov ax, 0x3D02
    mov dx, fname_cache
    int 0x21
    jc fail_cache
    mov [h_cache_b], ax

    mov bx, [h_cache_a]
    xor cx, cx
    mov dx, 1536
    xor al, al
    mov ah, 0x42
    int 0x21
    jc fail_cache
    mov bx, [h_cache_a]
    mov ah, 0x3F
    mov cx, 512
    mov dx, rbuf512
    int 0x21
    jc fail_cache
    cmp ax, 512
    jne fail_cache

    mov bx, [h_cache_b]
    xor cx, cx
    mov dx, 512
    xor al, al
    mov ah, 0x42
    int 0x21
    jc fail_cache
    mov bx, [h_cache_b]
    mov ah, 0x40
    xor cx, cx
    int 0x21
    jc fail_cache

    mov bx, [h_cache_a]
    xor cx, cx
    mov dx, 1536
    xor al, al
    mov ah, 0x42
    int 0x21
    jc fail_cache
    mov bx, [h_cache_a]
    mov ah, 0x3F
    mov cx, 512
    mov dx, rbuf512
    int 0x21
    jc fail_cache
    test ax, ax
    jnz fail_cache

    mov bx, [h_cache_b]
    mov ah, 0x3E
    int 0x21
    jc fail_cache
    mov bx, [h_cache_a]
    mov ah, 0x3E
    int 0x21
    jc fail_cache
    ret

fail_setup:
    mov dx, msg_fail_setup
    jmp fail
fail_trunc:
    mov dx, msg_fail_trunc
    jmp fail
fail_size:
    mov dx, msg_fail_size
    jmp fail
fail_persist:
    mov dx, msg_fail_persist
    jmp fail
fail_free:
    mov dx, msg_fail_free
    jmp fail
fail_cache:
    mov dx, msg_fail_cache
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
free_before: dw 0
fname: db "TRUNC.DAT", 0
msg_size:        db "PASS: TRUNC0 SIZE", 13, 10, '$'
msg_persist:     db "PASS: TRUNC0 PERSIST", 13, 10, '$'
msg_free:        db "PASS: TRUNC0 FREE", 13, 10, '$'
msg_cache:       db "PASS: TRUNC0 CACHE", 13, 10, '$'
msg_fail_setup:  db "FAIL: TRUNC0 SETUP", 13, 10, '$'
msg_fail_trunc:  db "FAIL: TRUNC0 TRUNC", 13, 10, '$'
msg_fail_size:   db "FAIL: TRUNC0 SIZE", 13, 10, '$'
msg_fail_persist: db "FAIL: TRUNC0 PERSIST", 13, 10, '$'
msg_fail_free:   db "FAIL: TRUNC0 FREE", 13, 10, '$'
msg_fail_cache:  db "FAIL: TRUNC0 CACHE", 13, 10, '$'

buf512: times 512 db 0x77
fname_cache: db "TCACHE.DAT", 0
h_cache_a: dw 0
h_cache_b: dw 0
rbuf512: times 512 db 0
