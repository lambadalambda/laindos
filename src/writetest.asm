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

    mov bx, 2
    mov cx, write_msg_end - write_msg
    mov dx, write_msg - image_start
    mov ah, 0x40
    int 0x21
    jc .fail_write
    cmp ax, write_msg_end - write_msg
    jne .fail_write

    mov bx, 0xFFFF
    xor cx, cx
    mov dx, write_msg - image_start
    mov ah, 0x40
    int 0x21
    jnc .fail_invalid
    cmp ax, 6
    jne .fail_invalid

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_write:
    mov dx, fail_msg - image_start
    jmp .print_fail
.fail_invalid:
    mov dx, fail_invalid_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

write_msg: db "WRITE-STDERR", 13, 10
write_msg_end:
pass_msg: db "PASS: WRITE$"
fail_msg: db "FAIL: WRITE$"
fail_invalid_msg: db "FAIL: WRITE INVALID$"

file_end:
