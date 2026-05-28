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
    mov ax, ds
    add ax, 0x10
    cmp ax, 0x1000
    jae pass

fail:
    push cs
    pop ds
    mov ah, 0x09
    mov dx, fail_msg - image_start
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass:
    push cs
    pop ds
    mov ah, 0x09
    mov dx, pass_msg - image_start
    int 0x21
    mov ax, 0x4C00
    int 0x21

pass_msg: db "PASS: PACKSEG", 13, 10, "$"
fail_msg: db "FAIL: PACKSEG", 13, 10, "$"

file_end:
