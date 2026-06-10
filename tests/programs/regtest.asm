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
    mov cx, 5
    mov dx, buf - image_start
    mov ah, 0x3F
    int 0x21
    jc .fail_read
    cmp ax, 5
    jne .fail_read
    cmp bx, [handle - image_start]
    jne .fail_regs
    cmp cx, 5
    jne .fail_regs
    cmp dx, buf - image_start
    jne .fail_regs

    mov bx, [handle - image_start]
    mov cx, 0
    mov dx, 1
    mov si, 0xBEEF
    mov di, 0xCAFE
    mov ax, 0x4200
    int 0x21
    jc .fail_seek
    cmp ax, 1
    jne .fail_seek
    cmp dx, 0
    jne .fail_seek
    cmp bx, [handle - image_start]
    jne .fail_regs
    cmp cx, 0
    jne .fail_regs
    cmp si, 0xBEEF
    jne .fail_regs
    cmp di, 0xCAFE
    jne .fail_regs

    mov bx, [handle - image_start]
    mov ah, 0x3E
    int 0x21
    jc .fail_close

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
    jmp .print_fail
.fail_regs:
    mov dx, fail_regs_msg - image_start
    jmp .print_fail
.fail_seek:
    mov dx, fail_seek_msg - image_start
    jmp .print_fail
.fail_close:
    mov dx, fail_close_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "TESTFILE.DAT", 0
pass_msg: db 13, 10, "PASS: REGS$"
fail_open_msg: db "FAIL: REGS OPEN$"
fail_read_msg: db "FAIL: REGS READ$"
fail_regs_msg: db "FAIL: REGS CLOBBER$"
fail_seek_msg: db "FAIL: REGS SEEK$"
fail_close_msg: db "FAIL: REGS CLOSE$"
handle: dw 0
buf: times 16 db 0

file_end:
