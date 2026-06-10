[bits 16]

hdr_size equ 4

mz_header:
    dw 0x5A4D
    dw (file_end - mz_header) % 512
    dw ((file_end - mz_header) + 511) / 512
    dw 0
    dw hdr_size
    dw 0x1100
    dw 0x1100
    dw 0x0000
    dw 0xFFFE
    dw 0x0000
    dw 0x0000
    dw 0x0000
    dw 0x001C
    dw 0x0000
    times (hdr_size * 16) - ($ - mz_header) db 0

image_start:
    push cs
    pop ds

    mov dx, filename - image_start
    mov ax, 0x3D00
    int 0x21
    jc .fail_open
    mov [handle - image_start], ax

    mov bx, 0x1100
    mov ah, 0x48
    int 0x21
    jc .fail_alloc
    mov [block_seg - image_start], ax

    mov es, ax
    xor di, di
    mov al, 0xA5
    mov cx, 256
    rep stosb

    mov ax, [block_seg - image_start]
    mov ds, ax
    mov di, 0xFF00
    mov al, 0xCC
    mov cx, 256
    rep stosb

    mov ax, [cs:block_seg - image_start]
    add ax, 0x1000
    mov es, ax
    xor di, di
    mov al, 0xCC
    mov cx, 256
    rep stosb

    mov ax, [cs:block_seg - image_start]
    mov ds, ax
    mov dx, 0xFF00
    mov bx, [cs:handle - image_start]
    mov cx, 512
    mov ah, 0x3F
    int 0x21
    jc .fail_read_cs
    cmp ax, 512
    jne .fail_read_cs

    cmp byte [0], 0xA5
    jne .fail_wrap_cs


    mov si, 0xFF00
    xor bl, bl
    mov cx, 256
.check_low:
    cmp [si], bl
    jne .fail_wrap_cs
    inc si
    inc bl
    loop .check_low

    mov ax, [cs:block_seg - image_start]
    add ax, 0x1000
    mov es, ax
    xor di, di
    xor bl, bl
    mov cx, 256
.check_high:
    cmp [es:di], bl
    jne .fail_wrap_cs
    inc di
    inc bl
    loop .check_high

    push cs
    pop ds
    mov bx, [handle - image_start]
    mov ah, 0x3E
    int 0x21

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_read_cs:
    push cs
    pop ds
    mov dx, fail_read_msg - image_start
    jmp .print_fail
.fail_wrap_cs:
    push cs
    pop ds
    mov dx, fail_wrap_msg - image_start
    jmp .print_fail
.fail_open:
    mov dx, fail_open_msg - image_start
    jmp .print_fail
.fail_alloc:
    mov dx, fail_alloc_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "READWRAP.DAT", 0
pass_msg: db 13, 10, "PASS: READWRAP$"
fail_open_msg: db "FAIL: READWRAP OPEN$"
fail_alloc_msg: db "FAIL: READWRAP ALLOC$"
fail_read_msg: db "FAIL: READWRAP READ$"
fail_wrap_msg: db "FAIL: READWRAP WRAP$"
handle: dw 0
block_seg: dw 0

file_end:
