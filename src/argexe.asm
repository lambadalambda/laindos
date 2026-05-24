[bits 16]

hdr_size equ 4

mz_header:
    dw 0x5A4D
    dw (file_end - mz_header) % 512
    dw ((file_end - mz_header) + 511) / 512
    dw 0
    dw hdr_size
    dw 0x0010
    dw 0xFFFF
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
    pop es
    mov si, expected - image_start
    mov di, 0x81
    xor cx, cx
    mov cl, [0x80]
    cmp cl, expected_len
    jne fail
.loop:
    mov al, [es:si]
    cmp al, [di]
    jne fail
    inc si
    inc di
    loop .loop
    push cs
    pop ds
    mov ah, 0x09
    mov dx, pass_msg - image_start
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail:
    push cs
    pop ds
    mov ah, 0x09
    mov dx, fail_msg - image_start
    int 0x21
    mov ax, 0x4C01
    int 0x21

expected: db " GDEMO /3"
expected_len equ $ - expected
pass_msg: db "PASS: ARGEXE", 13, 10, "$"
fail_msg: db "FAIL: ARGEXE", 13, 10, "$"

file_end:
