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
    cmp bx, 2
    jb .fail_buttons

    mov ax, 0x0004
    mov cx, 123
    mov dx, 45
    int 0x33

    mov ax, 0x0003
    int 0x33
    cmp cx, 123
    jne .fail_pos
    cmp dx, 45
    jne .fail_pos

    mov ax, 0x0007
    mov cx, 10
    mov dx, 20
    int 0x33

    mov ax, 0x0008
    mov cx, 30
    mov dx, 40
    int 0x33

    mov ax, 0x0004
    xor cx, cx
    xor dx, dx
    int 0x33

    mov ax, 0x0003
    int 0x33
    cmp cx, 10
    jne .fail_range
    cmp dx, 30
    jne .fail_range

    mov ax, 0x0004
    mov cx, 100
    mov dx, 100
    int 0x33

    mov ax, 0x0003
    int 0x33
    cmp cx, 20
    jne .fail_range
    cmp dx, 40
    jne .fail_range

    mov ax, 0x0001
    int 0x33
    mov ax, 0x0002
    int 0x33

    mov ax, 0x0005
    xor bx, bx
    int 0x33
    cmp ax, 0
    jne .fail_button_data
    cmp bx, 0
    jne .fail_button_data
    mov ax, 0x0006
    xor bx, bx
    int 0x33
    cmp ax, 0
    jne .fail_button_data
    cmp bx, 0
    jne .fail_button_data

    mov ax, 0x000B
    int 0x33
    cmp cx, 0
    jne .fail_motion
    cmp dx, 0
    jne .fail_motion

    ; AX=0024h: driver version, mouse type, IRQ. PS/2 mice report type 4
    ; and IRQ 0; protected-mode games (Settlers II) read these to pick
    ; their input path.
    xor bx, bx
    xor cx, cx
    mov ax, 0x0024
    int 0x33
    cmp bh, 6
    jb .fail_info
    cmp ch, 4
    jne .fail_info
    cmp cl, 0
    jne .fail_info

    ; AX=0015h: state buffer size must be a small nonzero byte count
    xor bx, bx
    mov ax, 0x0015
    int 0x33
    test bx, bx
    jz .fail_info
    cmp bx, 0x200
    ja .fail_info

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

.fail_reset:
    mov dx, fail_reset_msg - image_start
    jmp .print_fail
.fail_buttons:
    mov dx, fail_buttons_msg - image_start
    jmp .print_fail
.fail_pos:
    mov dx, fail_pos_msg - image_start
    jmp .print_fail
.fail_range:
    mov dx, fail_range_msg - image_start
    jmp .print_fail
.fail_button_data:
    mov dx, fail_button_data_msg - image_start
    jmp .print_fail
.fail_info:
    mov dx, fail_info_msg - image_start
    jmp .print_fail
.fail_motion:
    mov dx, fail_motion_msg - image_start
.print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass_msg: db 13, 10, "PASS: MOUSE$"
fail_reset_msg: db "FAIL: MOUSE RESET$"
fail_buttons_msg: db "FAIL: MOUSE BUTTONS$"
fail_pos_msg: db "FAIL: MOUSE POS$"
fail_range_msg: db "FAIL: MOUSE RANGE$"
fail_button_data_msg: db "FAIL: MOUSE BUTTON DATA$"
fail_info_msg: db 'FAIL: MOUSE INFO', 13, 10, '$'
fail_motion_msg: db "FAIL: MOUSE MOTION$"

file_end:
