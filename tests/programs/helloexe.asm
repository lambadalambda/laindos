[bits 16]

hdr_size equ 4

mz_header:
    dw 0x5A4D
    dw (file_end - mz_header) % 512
    dw ((file_end - mz_header) + 511) / 512
    dw 1
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

reloc_table:
    dw (reloc_target - image_start)
    dw 0x0000
    times (hdr_size * 16) - ($ - mz_header) db 0

image_start:
    push cs
    pop ds
    mov bx, reloc_target - image_start
    mov ax, [bx]
    test ax, ax
    jz .fail
    mov ds, ax
    mov ah, 0x09
    mov dx, msg - image_start
    int 0x21
    mov ah, 0x4C
    mov al, 0x00
    int 0x21
.fail:
    mov ah, 0x4C
    mov al, 0xFF
    int 0x21

msg: db "PASS: HELLO.EXE", 13, 10, "$"

reloc_target:
    dw 0x0000

file_end:
