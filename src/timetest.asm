[bits 16]
[org 0x0100]

start:
    mov ah, 0x2C
    int 0x21
    mov [first_cx], cx
    mov [first_dx], dx

    xor ah, ah
    int 0x1A
    mov [start_tick_lo], dx
    mov [start_tick_hi], cx
    mov si, 0xFFFF

.wait_tick:
    xor ah, ah
    int 0x1A
    cmp dx, [start_tick_lo]
    jne .got_tick
    cmp cx, [start_tick_hi]
    jne .got_tick
    dec si
    jnz .wait_tick
    jmp fail

.got_tick:
    mov ah, 0x2C
    int 0x21
    cmp cx, [first_cx]
    jne .check_high
    cmp dx, [first_dx]
    jne .check_high
    jmp fail

.check_high:
    push ds
    mov ax, 0x0040
    mov ds, ax
    mov ax, [0x006C]
    mov [cs:orig_tick_lo], ax
    mov ax, [0x006E]
    mov [cs:orig_tick_hi], ax
    mov word [0x006C], 0x0000
    mov word [0x006E], 0x0001
    pop ds

    mov ah, 0x2C
    int 0x21
    cmp ch, 1
    jne fail_restore
    call restore_ticks
    jmp pass

fail_restore:
    call restore_ticks

fail:
    mov dx, fail_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

pass:
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

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

first_cx: dw 0
first_dx: dw 0
start_tick_lo: dw 0
start_tick_hi: dw 0
orig_tick_lo: dw 0
orig_tick_hi: dw 0
pass_msg: db "PASS: TIME", 13, 10, "$"
fail_msg: db "FAIL: TIME", 13, 10, "$"
