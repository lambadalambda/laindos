%include "tests/programs/common.inc"

COM_START
    cld
    PRINT_DOLLAR msg_start
    mov dx, msg_phase_same
    mov al, 0
    mov cx, 64
    call run_phase
    mov dx, msg_phase_seq
    mov al, 1
    mov cx, 96
    call run_phase
    mov dx, msg_phase_alt2
    mov al, 2
    mov cx, 64
    call run_phase
    mov dx, msg_phase_alt4
    mov al, 3
    mov cx, 64
    call run_phase
    PASS_WITH msg_pass

run_phase:
    mov [phase_msg], dx
    mov [phase_kind], al
    mov [loop_count], cx
    mov dx, [phase_msg]
    mov ah, 0x09
    int 0x21
    mov dx, fname_archive
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax
    call counters_begin
    mov word [phase_index], 0
.loop:
    call calc_offset
    mov bx, [handle]
    xor cx, cx
    mov dx, [read_offset]
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    mov bx, [handle]
    mov dx, read_buf
    mov cx, 64
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 64
    jne fail_read
    mov di, [read_offset]
    call verify64
    jc fail_verify
    inc word [phase_index]
    dec word [loop_count]
    jnz .loop
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    call phase_end
    ret

calc_offset:
    xor ax, ax
    mov al, [phase_kind]
    test al, al
    jz .same
    cmp al, 1
    je .seq
    cmp al, 2
    je .alt2
    mov ax, [phase_index]
    and ax, 3
    jmp .sector_scale
.alt2:
    mov ax, [phase_index]
    and ax, 1
.sector_scale:
    mov cl, 11
    shl ax, cl
    jmp .store
.seq:
    mov ax, [phase_index]
    mov cl, 6
    shl ax, cl
    jmp .store
.same:
    xor ax, ax
.store:
    mov [read_offset], ax
    ret

counters_begin:
    mov ax, 0xF000
    int 0x21
    jc fail_perfapi
    call read_ticks
    mov [tick_start_lo], dx
    ret

phase_end:
    call read_ticks
    sub dx, [tick_start_lo]
    mov [elapsed_ticks], dx
    call print_ticks
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

verify64:
    push si
    push di
    mov si, read_buf
    mov cx, 64
.verify_loop:
    mov ax, di
    mov bl, al
    xor bl, ah
    cmp [si], bl
    jne .bad
    inc si
    inc di
    loop .verify_loop
    pop di
    pop si
    clc
    ret
.bad:
    pop di
    pop si
    stc
    ret

fail_open:
    mov dx, msg_fail_open
    jmp fail
fail_seek:
    mov dx, msg_fail_seek
    jmp fail
fail_read:
    mov dx, msg_fail_read
    jmp fail
fail_close:
    mov dx, msg_fail_close
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

msg_start: db "BENCH: PERFCD", 13, 10, "$"
msg_phase_same: db "BENCH: CDSAME64", 13, 10, "$"
msg_phase_seq: db "BENCH: CDSEQ64", 13, 10, "$"
msg_phase_alt2: db "BENCH: CDALT2_64", 13, 10, "$"
msg_phase_alt4: db "BENCH: CDALT4_64", 13, 10, "$"
msg_ticks: db "TICKS=", "$"
msg_crlf_dollar: db 13, 10, "$"
msg_pass: db "PASS: PERFCD", 13, 10, "$"
msg_fail_open: db "FAIL: PERFCD OPEN", 13, 10, "$"
msg_fail_seek: db "FAIL: PERFCD SEEK", 13, 10, "$"
msg_fail_read: db "FAIL: PERFCD READ", 13, 10, "$"
msg_fail_close: db "FAIL: PERFCD CLOSE", 13, 10, "$"
msg_fail_verify: db "FAIL: PERFCD VERIFY", 13, 10, "$"
msg_fail_perfapi: db "FAIL: PERFCD PERFAPI", 13, 10, "$"

fname_archive: db "D:\ARCHIVE.BIN", 0

handle: dw 0
phase_msg: dw 0
phase_kind: db 0
loop_count: dw 0
phase_index: dw 0
read_offset: dw 0
tick_start_lo: dw 0
elapsed_ticks: dw 0
read_buf: times 64 db 0
