[bits 16]
[org 0x0100]

MAX_DYNAMIC_HANDLES equ 15

start:
    push cs
    pop ds

    mov bx, 0
    call set_handle_count
    jc fail_set_zero

    mov bx, 1
    call set_handle_count
    jc fail_set_small
    call exhaust_handles
    jc fail_minimum
    cmp word [open_count], MAX_DYNAMIC_HANDLES
    jne fail_minimum
    cmp word [last_error], 4
    jne fail_minimum
    call close_open_handles
    jc fail_close

    mov bx, 20
    call set_handle_count
    jc fail_set_twenty

    mov bx, 40
    call set_handle_count
    jc fail_set_large
    call exhaust_handles
    jc fail_cap
    cmp word [open_count], MAX_DYNAMIC_HANDLES
    jne fail_cap
    cmp word [last_error], 4
    jne fail_cap
    call close_open_handles
    jc fail_close

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

set_handle_count:
    mov ah, 0x67
    int 0x21
    ret

exhaust_handles:
    mov word [open_count], 0
    mov word [last_error], 0
.loop:
    mov dx, self_name
    mov ax, 0x3D00
    int 0x21
    jc .full
    mov bx, [open_count]
    cmp bx, MAX_DYNAMIC_HANDLES
    jae .too_many
    shl bx, 1
    mov [handle_buf + bx], ax
    inc word [open_count]
    jmp .loop
.full:
    mov [last_error], ax
    clc
    ret
.too_many:
    mov word [last_error], 0xFFFF
    stc
    ret

close_open_handles:
    xor si, si
    mov cx, [open_count]
.loop:
    test cx, cx
    jz .done
    mov bx, [handle_buf + si]
    mov ah, 0x3E
    int 0x21
    jc .done
    add si, 2
    dec cx
    jmp .loop
.done:
    ret

fail_set_zero:
    mov dx, fail_set_zero_msg
    jmp fail
fail_set_small:
    mov dx, fail_set_small_msg
    jmp fail
fail_minimum:
    mov dx, fail_minimum_msg
    jmp fail
fail_set_twenty:
    mov dx, fail_set_twenty_msg
    jmp fail
fail_set_large:
    mov dx, fail_set_large_msg
    jmp fail
fail_cap:
    mov dx, fail_cap_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

self_name: db "HCOUNT.COM", 0
open_count: dw 0
last_error: dw 0
handle_buf: times MAX_DYNAMIC_HANDLES dw 0

pass_msg: db "PASS: HANDLECNT", 13, 10, "$"
fail_set_zero_msg: db "FAIL: HANDLECNT SET ZERO", 13, 10, "$"
fail_set_small_msg: db "FAIL: HANDLECNT SET SMALL", 13, 10, "$"
fail_minimum_msg: db "FAIL: HANDLECNT MINIMUM", 13, 10, "$"
fail_set_twenty_msg: db "FAIL: HANDLECNT SET TWENTY", 13, 10, "$"
fail_set_large_msg: db "FAIL: HANDLECNT SET LARGE", 13, 10, "$"
fail_cap_msg: db "FAIL: HANDLECNT CAP", 13, 10, "$"
fail_close_msg: db "FAIL: HANDLECNT CLOSE", 13, 10, "$"
