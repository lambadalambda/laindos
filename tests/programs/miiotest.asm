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

    mov dx, file901 - image_start
    mov al, 0
    mov ah, 0x3D
    int 0x21
    jc fail_open901
    mov [handle - image_start], ax

    mov bx, ax
    xor cx, cx
    mov dx, 0x0015
    mov ax, 0x4200
    int 0x21
    jc fail_seek901

    mov bx, [handle - image_start]
    mov dx, buf - image_start
    mov cx, 0x08C3
    mov ah, 0x3F
    int 0x21
    jc fail_read901
    cmp ax, 0x08C3
    jne fail_count901

    mov si, buf - image_start
    mov cx, 0x08C3
    call checksum
    cmp ax, 0xF5BE
    jne fail_sum901

    mov bx, [handle - image_start]
    mov ah, 0x3E
    int 0x21

    mov dx, disk01 - image_start
    mov al, 0
    mov ah, 0x3D
    int 0x21
    jc fail_openlec
    mov [handle - image_start], ax

    mov bx, ax
    xor cx, cx
    mov dx, 0x000C
    mov ax, 0x4200
    int 0x21
    jc fail_seeklec1

    mov bx, [handle - image_start]
    mov dx, buf - image_start
    mov cx, 0x0029
    mov ah, 0x3F
    int 0x21
    jc fail_readlec1
    cmp ax, 0x0029
    jne fail_countlec1

    mov si, buf - image_start
    mov cx, 0x0029
    call checksum
    cmp ax, 0x1270
    jne fail_sumlec1

    mov bx, [handle - image_start]
    xor cx, cx
    mov dx, 0x1B18
    mov ax, 0x4200
    int 0x21
    jc fail_seeklec2

    mov bx, [handle - image_start]
    mov dx, buf - image_start
    mov cx, 0x03F5
    mov ah, 0x3F
    int 0x21
    jc fail_readlec2
    cmp ax, 0x03F5
    jne fail_countlec2

    mov si, buf - image_start
    mov cx, 0x03F5
    call checksum
    cmp ax, 0x219E
    jne fail_sumlec2

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

checksum:
    xor bx, bx
.loop:
    lodsb
    xor ah, ah
    add bx, ax
    loop .loop
    mov ax, bx
    ret

fail_open901:  mov dx, msg_open901 - image_start
               jmp print_fail
fail_seek901:  mov dx, msg_seek901 - image_start
               jmp print_fail
fail_read901:  mov dx, msg_read901 - image_start
               jmp print_fail
fail_count901: mov dx, msg_count901 - image_start
               jmp print_fail
fail_sum901:   mov dx, msg_sum901 - image_start
               jmp print_fail
fail_openlec:  mov dx, msg_openlec - image_start
               jmp print_fail
fail_seeklec1: mov dx, msg_seeklec1 - image_start
               jmp print_fail
fail_readlec1: mov dx, msg_readlec1 - image_start
               jmp print_fail
fail_countlec1: mov dx, msg_countlec1 - image_start
                jmp print_fail
fail_sumlec1:  mov dx, msg_sumlec1 - image_start
               jmp print_fail
fail_seeklec2: mov dx, msg_seeklec2 - image_start
               jmp print_fail
fail_readlec2: mov dx, msg_readlec2 - image_start
               jmp print_fail
fail_countlec2: mov dx, msg_countlec2 - image_start
                jmp print_fail
fail_sumlec2:  mov dx, msg_sumlec2 - image_start

print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

file901: db "901.lfl", 0
disk01: db "disk01.lec", 0
pass_msg: db 13, 10, "PASS: MI IO$"
msg_open901: db "FAIL: OPEN 901$"
msg_seek901: db "FAIL: SEEK 901$"
msg_read901: db "FAIL: READ 901$"
msg_count901: db "FAIL: COUNT 901$"
msg_sum901: db "FAIL: SUM 901$"
msg_openlec: db "FAIL: OPEN LEC$"
msg_seeklec1: db "FAIL: SEEK LEC1$"
msg_readlec1: db "FAIL: READ LEC1$"
msg_countlec1: db "FAIL: COUNT LEC1$"
msg_sumlec1: db "FAIL: SUM LEC1$"
msg_seeklec2: db "FAIL: SEEK LEC2$"
msg_readlec2: db "FAIL: READ LEC2$"
msg_countlec2: db "FAIL: COUNT LEC2$"
msg_sumlec2: db "FAIL: SUM LEC2$"
handle: dw 0
buf: times 0x1000 db 0

file_end:
