%include "tests/programs/common.inc"

COM_START
    cld
    push cs
    pop es
    mov sp, 0x7FFE
    mov bx, 0x0800
    mov ah, 0x4A
    int 0x21
    jc fail_resize
    push cs
    pop ds
    mov [exec_params+4], ds

    PRINT_DOLLAR msg_start
    mov dx, msg_phase_read64
    mov ax, 64
    mov cx, 1024
    call run_seq_read_phase
    mov dx, msg_phase_read512
    mov ax, 512
    mov cx, 128
    call run_seq_read_phase
    mov dx, msg_phase_read1k
    mov ax, 1024
    mov cx, 64
    call run_seq_read_phase
    mov dx, msg_phase_read4k
    mov ax, 4096
    mov cx, 16
    call run_seq_read_phase
    call run_exec_load_phase
    call run_fat_seek_phase
    call run_dir_lookup_phase
    call run_cd_seq_phase
    PASS_WITH msg_pass

run_seq_read_phase:
    mov [phase_msg], dx
    mov [phase_chunk], ax
    mov [loop_count], cx
    mov dx, [phase_msg]
    mov ah, 0x09
    int 0x21
    mov dx, fname_readfat
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax
    call counters_begin
    mov word [verify_offset], 0
.loop:
    mov bx, [handle]
    mov dx, read_buf
    mov cx, [phase_chunk]
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, [phase_chunk]
    jne fail_read
    mov [verify_len], ax
    call verify_read_buf
    jc fail_verify
    mov ax, [phase_chunk]
    add [verify_offset], ax
    dec word [loop_count]
    jnz .loop
    call phase_end
    call close_handle
    ret

run_exec_load_phase:
    PRINT_DOLLAR msg_phase_exec
    call counters_begin
    push ds
    pop es
    mov bx, exec_params
    mov dx, fname_loadbig
    mov ax, 0x4B01
    int 0x21
    jc fail_exec
    call phase_end
    mov ax, [exec_params+0x14]
    mov es, ax
    mov ah, 0x49
    int 0x21
    push cs
    pop ds
    jc fail_free
    ret

run_fat_seek_phase:
    PRINT_DOLLAR msg_phase_seek
    mov dx, fname_readfat
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax
    call counters_begin
    mov word [phase_index], 0
    mov word [loop_count], seek_count
.loop:
    mov si, [phase_index]
    shl si, 1
    mov dx, [seek_offsets+si]
    mov [verify_offset], dx
    mov bx, [handle]
    xor cx, cx
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    mov bx, [handle]
    mov dx, read_buf
    mov cx, 512
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 512
    jne fail_read
    mov word [verify_len], 512
    call verify_read_buf
    jc fail_verify
    inc word [phase_index]
    dec word [loop_count]
    jnz .loop
    call phase_end
    call close_handle
    ret

run_dir_lookup_phase:
    PRINT_DOLLAR msg_phase_dir
    call counters_begin
    mov word [loop_count], 32
.loop:
    mov dx, fname_dir_target
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax
    call close_handle
    dec word [loop_count]
    jnz .loop
    call phase_end
    ret

run_cd_seq_phase:
    PRINT_DOLLAR msg_phase_cd
    mov dx, fname_cdseq
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [handle], ax
    call counters_begin
    mov word [verify_offset], 0
    mov word [loop_count], 64
.loop:
    mov bx, [handle]
    mov dx, read_buf
    mov cx, 512
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 512
    jne fail_read
    mov word [verify_len], 512
    call verify_read_buf
    jc fail_verify
    add word [verify_offset], 512
    dec word [loop_count]
    jnz .loop
    call phase_end
    call close_handle
    ret

close_handle:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
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

verify_read_buf:
    push ax
    push bx
    push cx
    push di
    push si
    mov si, read_buf
    mov di, [verify_offset]
    mov cx, [verify_len]
    jcxz .ok
.loop:
    mov ax, di
    mov bl, al
    xor bl, ah
    cmp [si], bl
    jne .bad
    inc si
    inc di
    loop .loop
.ok:
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    clc
    ret
.bad:
    pop si
    pop di
    pop cx
    pop bx
    pop ax
    stc
    ret

fail_resize:
    mov dx, msg_fail_resize
    jmp fail
fail_open:
    mov dx, msg_fail_open
    jmp fail
fail_read:
    mov dx, msg_fail_read
    jmp fail
fail_seek:
    mov dx, msg_fail_seek
    jmp fail
fail_close:
    mov dx, msg_fail_close
    jmp fail
fail_exec:
    mov dx, msg_fail_exec
    jmp fail
fail_free:
    mov dx, msg_fail_free
    jmp fail
fail_verify:
    mov dx, msg_fail_verify
    jmp fail
fail_perfapi:
    mov dx, msg_fail_perfapi
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    EXIT_CODE 1

msg_start: db "BENCH: PERFREAD", 13, 10, "$"
msg_phase_read64: db "BENCH: READ64", 13, 10, "$"
msg_phase_read512: db "BENCH: READ512", 13, 10, "$"
msg_phase_read1k: db "BENCH: READ1K", 13, 10, "$"
msg_phase_read4k: db "BENCH: READ4K", 13, 10, "$"
msg_phase_exec: db "BENCH: EXECLOAD", 13, 10, "$"
msg_phase_seek: db "BENCH: FATSEEK", 13, 10, "$"
msg_phase_dir: db "BENCH: DIRLOOK", 13, 10, "$"
msg_phase_cd: db "BENCH: CDSEQ", 13, 10, "$"
msg_ticks: db "TICKS=", "$"
msg_crlf_dollar: db 13, 10, "$"
msg_pass: db "PASS: PERFREAD", 13, 10, "$"
msg_fail_resize: db "FAIL: PERFREAD RESIZE", 13, 10, "$"
msg_fail_open: db "FAIL: PERFREAD OPEN", 13, 10, "$"
msg_fail_read: db "FAIL: PERFREAD READ", 13, 10, "$"
msg_fail_seek: db "FAIL: PERFREAD SEEK", 13, 10, "$"
msg_fail_close: db "FAIL: PERFREAD CLOSE", 13, 10, "$"
msg_fail_exec: db "FAIL: PERFREAD EXEC", 13, 10, "$"
msg_fail_free: db "FAIL: PERFREAD FREE", 13, 10, "$"
msg_fail_verify: db "FAIL: PERFREAD VERIFY", 13, 10, "$"
msg_fail_perfapi: db "FAIL: PERFREAD PERFAPI", 13, 10, "$"

fname_readfat: db "C:\READFAT.BIN", 0
fname_loadbig: db "C:\LOADBIG.COM", 0
fname_dir_target: db "C:\BIGDIR\TARGET.DAT", 0
fname_cdseq: db "D:\CDSEQ.BIN", 0
cmd_tail: db 0, 13
exec_params:
    dw 0
    dw cmd_tail, 0
    dw 0, 0
    dw 0, 0, 0, 0, 0, 0
seek_offsets:
    dw 0xF000, 0x0000, 0xE000, 0x1000
    dw 0xD000, 0x2000, 0xC000, 0x3000
    dw 0xB000, 0x4000, 0xA000, 0x5000
    dw 0x9000, 0x6000, 0x8000, 0x7000
    dw 0xF000, 0x0000, 0xE000, 0x1000
    dw 0xD000, 0x2000, 0xC000, 0x3000
    dw 0xB000, 0x4000, 0xA000, 0x5000
    dw 0x9000, 0x6000, 0x8000, 0x7000
seek_offsets_end:
seek_count equ (seek_offsets_end - seek_offsets) / 2

handle: dw 0
phase_msg: dw 0
phase_chunk: dw 0
loop_count: dw 0
phase_index: dw 0
tick_start_lo: dw 0
elapsed_ticks: dw 0
verify_offset: dw 0
verify_len: dw 0
read_buf: times 4096 db 0
