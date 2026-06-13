%include "tests/programs/common.inc"

COM_START
    cld

    PRINT_DOLLAR msg_start
    call run_full_sector_phase
    call run_small_record_phase
    call run_tiny_record_phase
    call run_read_before_close_check
    PASS_WITH msg_pass

run_full_sector_phase:
    PRINT_DOLLAR msg_phase_512
    mov dx, fname_512
    mov word [phase_writes], 128
    mov word [phase_bytes], 512
    call run_phase
    ret

run_small_record_phase:
    PRINT_DOLLAR msg_phase_128
    mov dx, fname_128
    mov word [phase_writes], 512
    mov word [phase_bytes], 128
    call run_phase
    ret

run_tiny_record_phase:
    PRINT_DOLLAR msg_phase_64
    mov dx, fname_64
    mov word [phase_writes], 1024
    mov word [phase_bytes], 64
    call run_phase
    ret

run_phase:
    mov [phase_name], dx
    call perf_reset
    call read_ticks
    mov [tick_start_lo], dx

    mov dx, [phase_name]
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov cx, [phase_writes]
.write_loop:
    push cx
    mov bx, [handle]
    mov dx, write_buf
    mov cx, [phase_bytes]
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, [phase_bytes]
    jne fail_write
    pop cx
    loop .write_loop

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    call read_ticks
    sub dx, [tick_start_lo]
    mov [elapsed_ticks], dx
    call print_ticks
    call perf_print
    call verify_phase
    ret

verify_phase:
    mov dx, [phase_name]
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax

    mov ax, [phase_writes]
    mov [verify_left], ax
.read_loop:
    mov bx, [handle]
    mov dx, read_buf
    mov cx, [phase_bytes]
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, [phase_bytes]
    jne fail_read
    call verify_buf
    jc fail_verify
    dec word [verify_left]
    jnz .read_loop

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

verify_buf:
    push cx
    push si
    mov si, read_buf
    mov cx, [phase_bytes]
.loop:
    cmp byte [si], 0x5A
    jne .bad
    inc si
    loop .loop
    pop si
    pop cx
    clc
    ret
.bad:
    pop si
    pop cx
    stc
    ret

run_read_before_close_check:
    push cs
    pop ds
    PRINT_DOLLAR msg_phase_rbc
    mov dx, fname_rbc
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, [handle]
    push cs
    pop ds
    mov dx, rbc_data
    mov cx, rbc_size
    mov ah, 0x40
    int 0x21
    jc fail_write_direct
    cmp ax, rbc_size
    jne fail_write_direct

    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jc fail_seek

    mov bx, [handle]
    push cs
    pop ds
    mov dx, read_buf
    mov cx, rbc_size
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, rbc_size
    jne fail_read
    push cs
    pop ds

    mov si, rbc_data
    mov di, read_buf
    mov cx, rbc_size
    push ds
    pop es
    repe cmpsb
    jne fail_verify

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

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

fail_open:
    mov dx, msg_fail_open
    jmp fail

fail_write:
    pop cx
fail_write_direct:
    mov dx, msg_fail_write
    jmp fail

fail_read:
    mov dx, msg_fail_read
    jmp fail

fail_close:
    mov dx, msg_fail_close
    jmp fail

fail_seek:
    mov dx, msg_fail_seek
    jmp fail

fail_verify:
    mov dx, msg_fail_verify
    jmp fail

fail_perfapi:
    mov dx, msg_fail_perfapi

fail:
    mov ah, 0x09
    int 0x21
    EXIT_CODE 1

msg_start: db "BENCH: PERFWRITE", 13, 10, "$"
msg_phase_512: db "BENCH: WRITE512", 13, 10, "$"
msg_phase_128: db "BENCH: WRITE128", 13, 10, "$"
msg_phase_64: db "BENCH: WRITE64", 13, 10, "$"
msg_phase_rbc: db "BENCH: READBEFORECLOSE", 13, 10, "$"
msg_ticks: db "TICKS=", "$"
msg_crlf_dollar: db 13, 10, "$"
msg_pass: db "PASS: PERFWRITE", 13, 10, "$"
msg_fail_create: db "FAIL: PERFWRITE CREATE", 13, 10, "$"
msg_fail_open: db "FAIL: PERFWRITE OPEN", 13, 10, "$"
msg_fail_write: db "FAIL: PERFWRITE WRITE", 13, 10, "$"
msg_fail_read: db "FAIL: PERFWRITE READ", 13, 10, "$"
msg_fail_close: db "FAIL: PERFWRITE CLOSE", 13, 10, "$"
msg_fail_seek: db "FAIL: PERFWRITE SEEK", 13, 10, "$"
msg_fail_verify: db "FAIL: PERFWRITE VERIFY", 13, 10, "$"
msg_fail_perfapi: db "FAIL: PERFWRITE PERFAPI", 13, 10, "$"
fname_512: db "C:\PERF512.DAT", 0
fname_128: db "C:\PERF128.DAT", 0
fname_64: db "C:\PERF64.DAT", 0
fname_rbc: db "C:\PERFRBC.DAT", 0
handle: dw 0
phase_name: dw 0
phase_writes: dw 0
phase_bytes: dw 0
tick_start_lo: dw 0
elapsed_ticks: dw 0
verify_left: dw 0
rbc_data: db "dirty cache readback"
rbc_size equ $ - rbc_data
write_buf: times 512 db 0x5A
read_buf: times 512 db 0
