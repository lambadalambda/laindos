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
    pop ds

    xor ax, ax
    int 0x33
    cmp ax, 0xFFFF
    jne .fail_reset

    mov dx, ready_msg - image_start
    mov ah, 0x09
    int 0x21

.loop:
    mov ax, 0x000B
    int 0x33
    cmp cx, 0
    jne .pass
    cmp dx, 0
    jne .pass
    jmp .loop

.pass:
    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_reset:
    mov dx, fail_reset_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

ready_msg: db 13, 10, "READY: MOUSEHW$"
pass_msg: db 13, 10, "PASS: MOUSEHW$"
fail_reset_msg: db "FAIL: MOUSEHW RESET$"

file_end:
