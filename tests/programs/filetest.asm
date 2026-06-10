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
    mov al, 0
    mov ah, 0x3D
    int 0x21
    jc .fail_open

    mov [handle - image_start], ax
    mov bx, ax
    mov dx, buf - image_start
    mov cx, 5
    mov ah, 0x3F
    int 0x21
    jc .fail_read

    mov bx, [handle - image_start]
    mov ah, 0x3E
    int 0x21

    mov byte [buf + 5 - image_start], '$'
    mov dx, buf - image_start
    mov ah, 0x09
    int 0x21

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21

    mov dx, subdir - image_start
    mov al, 0
    mov ah, 0x3D
    int 0x21
    jc .fail_open_sub

    mov [handle2 - image_start], ax
    mov bx, ax
    mov dx, buf2 - image_start
    mov cx, 10
    mov ah, 0x3F
    int 0x21
    jc .fail_read

    mov bx, [handle2 - image_start]
    mov ah, 0x3E
    int 0x21

    mov byte [buf2 + 10 - image_start], '$'
    mov dx, buf2 - image_start
    mov ah, 0x09
    int 0x21

    mov dx, pass2_msg - image_start
    mov ah, 0x09
    int 0x21

    mov ah, 0x4C
    mov al, 0x00
    int 0x21

.fail_open:
    mov dx, fail_open_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ah, 0x4C
    mov al, 0x01
    int 0x21

.fail_open_sub:
    mov dx, fail_sub_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ah, 0x4C
    mov al, 0x03
    int 0x21

.fail_read:
    mov dx, fail_read_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ah, 0x4C
    mov al, 0x02
    int 0x21

filename: db "TESTFILE.DAT", 0
subdir: db "\MIDEMO\SUBTEST.DAT", 0
fail_open_msg: db "FAIL: OPEN$"
fail_sub_msg: db "FAIL: SUBDIR$"
fail_read_msg: db "FAIL: READ$"
pass_msg: db 13, 10, "PASS: ROOT$"
pass2_msg: db 13, 10, "PASS: SUBDIR$"
handle: dw 0
handle2: dw 0
buf: times 128 db 0
buf2: times 128 db 0

file_end:
