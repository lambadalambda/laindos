[bits 16]
[org 0x0100]

%ifndef EXPECT_HOUR
%error "EXPECT_HOUR must be defined"
%endif
%ifndef EXPECT_MIN
%error "EXPECT_MIN must be defined"
%endif
%ifndef BASE_HOUR
%define BASE_HOUR 0
%endif
%ifndef BASE_MIN
%define BASE_MIN 0
%endif
%if BASE_HOUR < 0 || BASE_HOUR > 23
%error "BASE_HOUR must be 0..23"
%endif
%if BASE_MIN < 0 || BASE_MIN > 59
%error "BASE_MIN must be 0..59"
%endif
%assign BASE_TICKS ((BASE_HOUR * 0x10007) + (BASE_MIN * 0x0444))

start:
    push cs
    pop ds
    call save_ticks
    call set_base_ticks

    mov ah, 0x2C
    int 0x21
    cmp ch, EXPECT_HOUR
    jne fail_restore
    cmp cl, EXPECT_MIN
    jne fail_restore
    cmp dh, 0
    jne fail_restore

    call restore_ticks
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_restore:
    call restore_ticks
fail:
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

save_ticks:
    push ax
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov ax, [0x006C]
    mov [cs:orig_tick_lo], ax
    mov ax, [0x006E]
    mov [cs:orig_tick_hi], ax
    pop ds
    pop ax
    ret

set_base_ticks:
    push ax
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov word [0x006C], BASE_TICKS & 0xFFFF
    mov word [0x006E], BASE_TICKS >> 16
    pop ds
    pop ax
    ret

restore_ticks:
    push ax
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov ax, [cs:orig_tick_lo]
    mov [0x006C], ax
    mov ax, [cs:orig_tick_hi]
    mov [0x006E], ax
    pop ds
    pop ax
    ret

orig_tick_lo: dw 0
orig_tick_hi: dw 0
pass_msg: db "PASS: TIMEOFFSET", 13, 10, "$"
fail_msg: db "FAIL: TIMEOFFSET", 13, 10, "$"
