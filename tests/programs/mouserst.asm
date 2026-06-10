[bits 16]
[org 0x0100]

%ifndef EXPECT_PRESENT
%define EXPECT_PRESENT 1
%endif

start:
    push cs
    pop ds

%if EXPECT_PRESENT
    xor ax, ax
    int 0x33
    cmp ax, 0xFFFF
    jne fail_reset

    mov dx, ready_msg
    mov ah, 0x09
    int 0x21

    mov cx, 0x0400
.wait_outer:
    push cx
    xor cx, cx
.wait_inner:
    mov ax, 0x0003
    int 0x33
    cmp cx, 320
    jne .moved_pop
    pop cx
    push cx
    xor cx, cx
    loop .wait_inner
    pop cx
    loop .wait_outer
    jmp fail_timeout
.moved_pop:
    pop cx
    mov ax, 0x0003
    int 0x33
    sub cx, 320
    sub dx, 100
    mov ax, dx
    shl ax, 1
    cmp ax, cx
    jne fail_ratio
    mov dx, msg_ratio
    mov ah, 0x09
    int 0x21
%else
    xor ax, ax
    int 0x33
    test ax, ax
    jnz fail_absent
    mov dx, msg_absent
    mov ah, 0x09
    int 0x21
%endif

    mov ax, 0x4C00
    int 0x21

%if EXPECT_PRESENT
fail_reset:
    mov dx, msg_fail_reset
    jmp fail
fail_timeout:
    mov dx, msg_fail_timeout
    jmp fail
fail_ratio:
    mov dx, msg_fail_ratio
    jmp fail
%else
fail_absent:
    mov dx, msg_fail_absent
    jmp fail
%endif
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

%if EXPECT_PRESENT
ready_msg:        db "READY: MOUSERST", 13, 10, '$'
msg_ratio:        db "PASS: MOUSERST RATIO", 13, 10, '$'
msg_fail_reset:   db "FAIL: MOUSERST RESET", 13, 10, '$'
msg_fail_timeout: db "FAIL: MOUSERST TIMEOUT", 13, 10, '$'
msg_fail_ratio:   db "FAIL: MOUSERST RATIO", 13, 10, '$'
%else
msg_absent:       db "PASS: MOUSERST ABSENT", 13, 10, '$'
msg_fail_absent:  db "FAIL: MOUSERST ABSENT", 13, 10, '$'
%endif
