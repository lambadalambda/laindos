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

    int 0x01
    int 0x06

    mov bx, 0x0100
    mov ah, 0x48
    int 0x21
    jc .fail1
    mov [block_a - image_start], ax

    mov es, ax
    mov byte [es:0x0000], 0xAA
    mov byte [es:0x0001], 0xBB
    cmp byte [es:0x0000], 0xAA
    jne .fail_v

    mov es, [block_a - image_start]
    mov bx, 0x0200
    mov ah, 0x4A
    int 0x21
    jc .fail2

    mov es, [block_a - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail3

    mov bx, 0x0080
    mov ah, 0x48
    int 0x21
    jc .fail4
    mov [block_b - image_start], ax

    mov bx, 0x0080
    mov ah, 0x48
    int 0x21
    jc .fail4b
    mov [block_c - image_start], ax

    mov es, [block_c - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail5

    mov es, [block_b - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail5

    mov bx, 0x0180
    mov ah, 0x48
    int 0x21
    jc .fail6
    mov [block_a - image_start], ax

    mov es, [block_a - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail3

    mov bx, 0x0100
    mov ah, 0x48
    int 0x21
    jc .fail8
    mov [block_a - image_start], ax

    mov bx, 0x0100
    mov ah, 0x48
    int 0x21
    jc .fail8
    mov [block_b - image_start], ax

    mov bx, 0x0100
    mov ah, 0x48
    int 0x21
    jc .fail8
    mov [block_c - image_start], ax

    mov es, [block_b - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail8

    mov es, [block_a - image_start]
    mov bx, 0x0080
    mov ah, 0x4A
    int 0x21
    jc .fail8

    mov bx, 0x0180
    mov ah, 0x48
    int 0x21
    jc .fail8
    mov dx, [block_a - image_start]
    add dx, 0x0081
    cmp ax, dx
    jne .fail8
    mov [block_d - image_start], ax

    mov es, [block_d - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail8

    mov es, [block_c - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail8

    mov es, [block_a - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail8

    mov bx, 0x0080
    mov ah, 0x48
    int 0x21
    jc .fail7
    mov [block_a - image_start], ax

    mov bx, 0x0080
    mov ah, 0x48
    int 0x21
    jc .fail7
    mov [block_b - image_start], ax

    mov es, [block_a - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail7

    mov ax, 0x5801
    mov bx, 0x0002
    int 0x21
    jc .fail7

    mov bx, 0x0010
    mov ah, 0x48
    int 0x21
    jc .fail7
    mov [block_c - image_start], ax

    mov ax, 0x5801
    xor bx, bx
    int 0x21
    jc .fail7

    mov ax, [block_c - image_start]
    cmp ax, [block_b - image_start]
    jbe .fail7

    mov es, [block_c - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail7

    mov es, [block_b - image_start]
    mov ah, 0x49
    int 0x21
    jc .fail7

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21

    mov ah, 0x4C
    mov al, 0x00
    int 0x21

.fail1:
    mov dx, fail1_msg - image_start
    jmp .print_fail
.fail_v:
    mov dx, fail_v_msg - image_start
    jmp .print_fail
.fail2:
    mov dx, fail2_msg - image_start
    jmp .print_fail
.fail3:
    mov dx, fail3_msg - image_start
    jmp .print_fail
.fail4:
    mov dx, fail4_msg - image_start
    jmp .print_fail
.fail4b:
    mov dx, fail4b_msg - image_start
    jmp .print_fail
.fail5:
    mov dx, fail5_msg - image_start
    jmp .print_fail
.fail6:
    mov dx, fail6_msg - image_start
    jmp .print_fail
.fail7:
    mov dx, fail7_msg - image_start
    jmp .print_fail
.fail8:
    mov dx, fail8_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ah, 0x4C
    mov al, 0x01
    int 0x21

block_a: dw 0
block_b: dw 0
block_c: dw 0
block_d: dw 0

pass_msg:  db 13, 10, "PASS: MEM$"
fail1_msg: db "FAIL: ALLOC1$"
fail_v_msg: db "FAIL: VERIFY$"
fail2_msg: db "FAIL: RESIZE$"
fail3_msg: db "FAIL: FREE$"
fail4_msg: db "FAIL: ALLOC2A$"
fail4b_msg: db "FAIL: ALLOC2B$"
fail5_msg: db "FAIL: FREE2$"
fail6_msg: db "FAIL: MERGE$"
fail7_msg: db "FAIL: STRATEGY$"
fail8_msg: db "FAIL: SHRINK MERGE$"

file_end:
