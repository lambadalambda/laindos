[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    xor ax, ax
    int 0x33
    cmp ax, 0xFFFF
    jne fail_reset

    push cs
    pop es
    mov dx, callback
    mov cx, 0x0001
    mov ax, 0x000C
    int 0x33

    mov dx, ready_msg
    mov ah, 0x09
    int 0x21

    mov cx, 0x0400
.wait_outer:
    push cx
    xor cx, cx
.wait_inner:
    cmp word [callback_seen], 1
    je .check_pop
    loop .wait_inner
    pop cx
    loop .wait_outer
    jmp fail_timeout
.check_pop:
    pop cx
.check:
    cmp word [tick_advanced], 1
    jne fail_ticks
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_reset:
    mov dx, fail_reset_msg
    jmp fail
fail_timeout:
    mov dx, fail_timeout_msg
    jmp fail
fail_ticks:
    mov dx, fail_ticks_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

callback:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es
    push cs
    pop ds
    cmp word [callback_seen], 1
    je .done
    mov ax, 0x0040
    mov es, ax
    mov dx, [es:0x006C]
    mov cx, 0x0400
.outer:
    push cx
    xor cx, cx
.inner:
    cmp [es:0x006C], dx
    jne .advanced_pop
    loop .inner
    pop cx
    loop .outer
    jmp .record
.advanced_pop:
    pop cx
    mov word [tick_advanced], 1
.record:
    mov word [callback_seen], 1
.done:
    pop es
    pop ds
    pop dx
    pop cx
    pop bx
    pop ax
    retf

callback_seen: dw 0
tick_advanced: dw 0
ready_msg:        db "READY: MOUSEEOI", 13, 10, '$'
pass_msg:         db "PASS: MOUSEEOI", 13, 10, '$'
fail_reset_msg:   db "FAIL: MOUSEEOI RESET", 13, 10, '$'
fail_timeout_msg: db "FAIL: MOUSEEOI TIMEOUT", 13, 10, '$'
fail_ticks_msg:   db "FAIL: MOUSEEOI TICKS", 13, 10, '$'
