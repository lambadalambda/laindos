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
    jne fail_reset

    mov ax, 0x0007
    xor cx, cx
    mov dx, 639
    int 0x33
    mov ax, 0x0008
    xor cx, cx
    mov dx, 199
    int 0x33

    mov ax, 0x0004
    xor cx, cx
    mov dx, 100
    int 0x33
    mov ax, 0x000F
    mov cx, 8
    mov dx, 8
    int 0x33

    mov dx, ready1_msg - image_start
    mov ah, 0x09
    int 0x21
    call wait_x
    jc fail_timeout1
    mov [x1 - image_start], cx

    mov ax, 0x0004
    xor cx, cx
    mov dx, 100
    int 0x33
    mov ax, 0x000F
    mov cx, 4
    mov dx, 8
    int 0x33

    mov dx, ready2_msg - image_start
    mov ah, 0x09
    int 0x21
    call wait_x
    jc fail_timeout2
    mov [x2 - image_start], cx

    cmp word [x1 - image_start], 8
    jb fail_motion
    mov ax, [x1 - image_start]
    add ax, 8
    cmp [x2 - image_start], ax
    jb fail_ratio

    mov ax, 0x0004
    xor cx, cx
    xor dx, dx
    int 0x33
    mov ax, 0x000F
    mov cx, 8
    mov dx, 8
    int 0x33
    mov ax, 0x000B
    int 0x33

    mov dx, ready3_msg - image_start
    mov ah, 0x09
    int 0x21
    call wait_motion
    jc fail_timeout3

    mov ax, 0x0003
    int 0x33
    cmp cx, 0
    jne fail_edge
    cmp dx, 0
    jne fail_edge

    mov ax, 0x0004
    mov cx, 639
    mov dx, 199
    int 0x33
    mov ax, 0x000B
    int 0x33

    mov dx, ready4_msg - image_start
    mov ah, 0x09
    int 0x21
    call wait_motion
    jc fail_timeout4

    mov ax, 0x0003
    int 0x33
    cmp cx, 639
    jne fail_edge
    cmp dx, 199
    jne fail_edge

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

wait_x:
    mov si, 0xFFFF
.loop:
    mov ax, 0x0003
    int 0x33
    test cx, cx
    jnz .ok
    sti
    hlt
    dec si
    jnz .loop
    stc
    ret
.ok:
    clc
    ret

wait_motion:
    mov si, 0xFFFF
.motion_loop:
    mov ax, 0x000B
    int 0x33
    mov ax, cx
    or ax, dx
    jnz .motion_ok
    sti
    hlt
    dec si
    jnz .motion_loop
    stc
    ret
.motion_ok:
    clc
    ret

fail_reset:
    mov dx, fail_reset_msg - image_start
    jmp print_fail
fail_timeout1:
    mov dx, fail_timeout1_msg - image_start
    jmp print_fail
fail_timeout2:
    mov dx, fail_timeout2_msg - image_start
    jmp print_fail
fail_timeout3:
    mov dx, fail_timeout3_msg - image_start
    jmp print_fail
fail_timeout4:
    mov dx, fail_timeout4_msg - image_start
    jmp print_fail
fail_motion:
    mov dx, fail_motion_msg - image_start
    jmp print_fail
fail_ratio:
    mov dx, fail_ratio_msg - image_start
    jmp print_fail
fail_edge:
    mov dx, fail_edge_msg - image_start
print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

x1: dw 0
x2: dw 0

ready1_msg: db 13, 10, "READY: MOUSERATIO 1$"
ready2_msg: db 13, 10, "READY: MOUSERATIO 2$"
ready3_msg: db 13, 10, "READY: MOUSERATIO EDGE$"
ready4_msg: db 13, 10, "READY: MOUSERATIO MAXEDGE$"
pass_msg: db 13, 10, "PASS: MOUSERATIO$"
fail_reset_msg: db "FAIL: MOUSERATIO RESET$"
fail_timeout1_msg: db "FAIL: MOUSERATIO TIMEOUT1$"
fail_timeout2_msg: db "FAIL: MOUSERATIO TIMEOUT2$"
fail_timeout3_msg: db "FAIL: MOUSERATIO TIMEOUT3$"
fail_timeout4_msg: db "FAIL: MOUSERATIO TIMEOUT4$"
fail_motion_msg: db "FAIL: MOUSERATIO MOTION$"
fail_ratio_msg: db "FAIL: MOUSERATIO RATIO$"
fail_edge_msg: db "FAIL: MOUSERATIO EDGE$"

file_end:
