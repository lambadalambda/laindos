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

    push cs
    pop es
    mov dx, callback - image_start
    mov cx, 0x0007
    mov ax, 0x000C
    int 0x33

    mov dx, ready_msg - image_start
    mov ah, 0x09
    int 0x21

    mov cx, 0x8000
wait_loop:
    mov ax, [callback_seen - image_start]
    and ax, 0x0007
    cmp ax, 0x0007
    je check_callback
    mov ax, 0x0003
    int 0x33
    loop wait_loop
    jmp fail_timeout

check_callback:
    cmp word [callback_motion_x - image_start], 0
    je fail_motion
    mov ax, 0x0005
    xor bx, bx
    int 0x33
    cmp bx, 0
    je fail_press_data
    mov ax, 0x0006
    xor bx, bx
    int 0x33
    cmp ax, 0
    jne fail_release_data
    cmp bx, 0
    je fail_release_data

    mov dx, pass_msg - image_start
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

callback:
    push ds
    push cs
    pop ds
    inc word [callback_count - image_start]
    or [callback_seen - image_start], ax
    test ax, 0x0001
    jz .store_common
    mov [callback_motion_x - image_start], si
.store_common:
    mov [callback_ax - image_start], ax
    mov [callback_bx - image_start], bx
    mov [callback_cx - image_start], cx
    mov [callback_dx - image_start], dx
    mov [callback_si - image_start], si
    mov [callback_di - image_start], di
    pop ds
    retf

fail_reset:
    mov dx, fail_reset_msg - image_start
    jmp print_fail
fail_timeout:
    mov dx, fail_timeout_msg - image_start
    jmp print_fail
fail_motion:
    mov dx, fail_motion_msg - image_start
    jmp print_fail
fail_press_data:
    mov dx, fail_press_data_msg - image_start
    jmp print_fail
fail_release_data:
    mov dx, fail_release_data_msg - image_start
print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

callback_count: dw 0
callback_seen: dw 0
callback_motion_x: dw 0
callback_ax: dw 0
callback_bx: dw 0
callback_cx: dw 0
callback_dx: dw 0
callback_si: dw 0
callback_di: dw 0

ready_msg: db 13, 10, "READY: MOUSECB$"
pass_msg: db 13, 10, "PASS: MOUSECB$"
fail_reset_msg: db "FAIL: MOUSECB RESET$"
fail_timeout_msg: db "FAIL: MOUSECB TIMEOUT$"
fail_motion_msg: db "FAIL: MOUSECB MOTION$"
fail_press_data_msg: db "FAIL: MOUSECB PRESSDATA$"
fail_release_data_msg: db "FAIL: MOUSECB RELEASEDATA$"

file_end:
