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

    mov dx, file000 - image_start
    mov ax, 0x3D00
    int 0x21
    jc .fail_open
    mov [handle - image_start], ax

    mov bx, ax
    mov dx, buf - image_start
    mov cx, 16
    mov ah, 0x3F
    int 0x21
    jc .fail_read
    cmp ax, 16
    jne .fail_read

    mov bx, [handle - image_start]
    mov ah, 0x3E
    int 0x21

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_open:
    mov dx, fail_open_msg - image_start
    jmp .print_fail
.fail_read:
    mov dx, fail_read_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

file000: db "MI2DEMO.000", 0
pass_msg: db 13, 10, "PASS: MI2 IO$"
fail_open_msg: db "FAIL: MI2 OPEN$"
fail_read_msg: db "FAIL: MI2 READ$"
handle: dw 0
buf: times 16 db 0

file_end:
