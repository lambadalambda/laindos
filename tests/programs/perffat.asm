%include "tests/programs/common.inc"

COM_START
    cld

    PRINT_DOLLAR msg_start
    PRINT_DOLLAR msg_phase
    call perf_reset
    call read_ticks
    mov [tick_start_lo], dx

    mov dx, fname_alloc
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov word [loop_count], 256
.write_loop:
    mov bx, [handle]
    mov dx, write_buf
    mov cx, 512
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 512
    jne fail_write
    dec word [loop_count]
    jnz .write_loop

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    call read_ticks
    sub dx, [tick_start_lo]
    mov [elapsed_ticks], dx
    call print_ticks
    call perf_print
    PASS_WITH msg_pass

perf_reset:
    mov ax, 0xF000
    int 0x21
    jc fail_perfapi
    ret

perf_print:
    mov ax, 0xF001
    int 0x21
    jc fail_perfapi
    ret

read_ticks:
    xor ah, ah
    int 0x1A
    ret

print_ticks:
    PRINT_DOLLAR msg_ticks
    mov ax, [elapsed_ticks]
    call print_hex_word
    PRINT_DOLLAR msg_crlf_dollar
    ret

print_hex_word:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov cx, 4
.digit:
    rol bx, 4
    mov dl, bl
    and dl, 0x0F
    cmp dl, 10
    jb .number
    add dl, 'A' - 10
    jmp .emit
.number:
    add dl, '0'
.emit:
    mov ah, 0x02
    int 0x21
    loop .digit
    pop dx
    pop cx
    pop bx
    pop ax
    ret

fail_create:
    mov dx, msg_fail_create
    jmp fail
fail_write:
    mov dx, msg_fail_write
    jmp fail
fail_close:
    mov dx, msg_fail_close
    jmp fail
fail_perfapi:
    mov dx, msg_fail_perfapi
fail:
    mov ah, 0x09
    int 0x21
    EXIT_CODE 1

msg_start: db "BENCH: PERFAT", 13, 10, "$"
msg_phase: db "BENCH: ALLOC", 13, 10, "$"
msg_ticks: db "TICKS=", "$"
msg_crlf_dollar: db 13, 10, "$"
msg_pass: db "PASS: PERFAT", 13, 10, "$"
msg_fail_create: db "FAIL: PERFAT CREATE", 13, 10, "$"
msg_fail_write: db "FAIL: PERFAT WRITE", 13, 10, "$"
msg_fail_close: db "FAIL: PERFAT CLOSE", 13, 10, "$"
msg_fail_perfapi: db "FAIL: PERFAT PERFAPI", 13, 10, "$"

fname_alloc: db "C:\FATALLOC.DAT", 0
handle: dw 0
loop_count: dw 0
tick_start_lo: dw 0
elapsed_ticks: dw 0
write_buf: times 512 db 0xC3
