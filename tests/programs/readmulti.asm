%include "tests/programs/common.inc"

block_paras equ 0x3000
misalign_target equ 0x0101
large_read_len equ 0xF000
large_read_paras equ large_read_len / 16

MZ_HEADER 0x1200, 0x1200

image_start:
    push cs
    pop ds

    mov dx, filename - image_start
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle - image_start], ax

    mov bx, block_paras
    mov ah, 0x48
    int 0x21
    jc fail_alloc
    mov [block_seg - image_start], ax

    call seek_start
    jc fail_seek
    mov ax, [block_seg - image_start]
    mov ds, ax
    mov dx, 0x000E
    mov bx, [cs:handle - image_start]
    mov cx, 0x20A5
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 0x20A5
    jne fail_read
    mov ax, [cs:block_seg - image_start]
    mov ds, ax
    mov si, 0x000E
    mov cx, 0x20A5
    xor bl, bl
    call check_linear
    jc fail_data

    call seek_start
    jc fail_seek
    call choose_misaligned_segment
    jc fail_segment
    mov ds, ax
    xor dx, dx
    mov bx, [cs:handle - image_start]
    mov cx, large_read_len
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, large_read_len
    jne fail_read
    mov ax, [cs:misaligned_seg - image_start]
    mov ds, ax
    xor si, si
    mov cx, large_read_len
    xor bl, bl
    call check_linear
    jc fail_data

    call seek_start
    jc fail_seek
    mov ax, [block_seg - image_start]
    mov ds, ax
    mov dx, 0xFE00
    mov bx, [cs:handle - image_start]
    mov cx, 1024
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 1024
    jne fail_read

    mov ax, [cs:block_seg - image_start]
    mov ds, ax
    mov si, 0xFE00
    mov cx, 512
    xor bl, bl
    call check_linear
    jc fail_data
    mov ax, [cs:block_seg - image_start]
    add ax, 0x1000
    mov ds, ax
    xor si, si
    mov cx, 512
    xor bl, bl
    call check_linear
    jc fail_data

    push cs
    pop ds
    mov bx, [handle - image_start]
    mov ah, 0x3E
    int 0x21
    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

seek_start:
    push cs
    pop ds
    mov bx, [handle - image_start]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    ret

choose_misaligned_segment:
    push bx
    push dx
    mov ax, [block_seg - image_start]
    mov dx, ax
    and dx, 0xF000
    mov ax, dx
    add ax, misalign_target
    cmp ax, [block_seg - image_start]
    jae .candidate_ready
    add ax, 0x1000
.candidate_ready:
    mov dx, ax
    add dx, large_read_paras
    mov bx, [block_seg - image_start]
    add bx, block_paras
    cmp dx, bx
    ja .bad
    mov [misaligned_seg - image_start], ax
    clc
    pop dx
    pop bx
    ret
.bad:
    stc
    pop dx
    pop bx
    ret

check_linear:
    cmp [si], bl
    jne .bad
    inc si
    inc bl
    loop check_linear
    clc
    ret
.bad:
    stc
    ret

fail_open:
    mov dx, fail_open_msg - image_start
    jmp print_fail
fail_alloc:
    mov dx, fail_alloc_msg - image_start
    jmp print_fail
fail_seek:
    push cs
    pop ds
    mov dx, fail_seek_msg - image_start
    jmp print_fail
fail_read:
    push cs
    pop ds
    mov dx, fail_read_msg - image_start
    jmp print_fail
fail_segment:
    push cs
    pop ds
    mov dx, fail_segment_msg - image_start
    jmp print_fail
fail_data:
    push cs
    pop ds
    mov dx, fail_data_msg - image_start
print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "READMULT.DAT", 0
pass_msg: db 13, 10, "PASS: READMULTI$"
fail_open_msg: db "FAIL: READMULTI OPEN$"
fail_alloc_msg: db "FAIL: READMULTI ALLOC$"
fail_seek_msg: db "FAIL: READMULTI SEEK$"
fail_read_msg: db "FAIL: READMULTI READ$"
fail_segment_msg: db "FAIL: READMULTI SEG$"
fail_data_msg: db "FAIL: READMULTI DATA$"
handle: dw 0
block_seg: dw 0
misaligned_seg: dw 0

file_end:
