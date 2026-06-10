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

    mov dx, filename - image_start
    mov ax, 0x3D00
    int 0x21
    jc .fail_open
    mov [handle - image_start], ax

    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc .fail_close1

    mov bx, [handle - image_start]
    mov ah, 0x3E
    int 0x21
    jnc .fail_close2
    cmp ax, 6
    jne .fail_close2

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_open:
    mov dx, fail_open_msg - image_start
    jmp .print_fail
.fail_close1:
    mov dx, fail_close1_msg - image_start
    jmp .print_fail
.fail_close2:
    mov dx, fail_close2_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "TESTFILE.DAT", 0
pass_msg: db 13, 10, "PASS: CLOSE$"
fail_open_msg: db "FAIL: CLOSE OPEN$"
fail_close1_msg: db "FAIL: CLOSE FIRST$"
fail_close2_msg: db "FAIL: CLOSE SECOND$"
handle: dw 0

file_end:
