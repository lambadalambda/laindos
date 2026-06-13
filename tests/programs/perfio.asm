%include "tests/programs/common.inc"

COM_START
    cld

    PRINT_DOLLAR msg_start
    call run_write512_phase
    call run_write128_phase
    call run_drive_switch_phase
    call run_fat16_alloc_phase
    call run_metadata_phase
    call run_cd_mix_phase
    PASS_WITH msg_pass

run_write512_phase:
    mov dx, msg_phase_512
    call phase_begin
    mov dx, fname_512
    mov word [phase_writes], 128
    mov word [phase_bytes], 512
    call run_write_body
    call phase_end
    ret

run_write128_phase:
    mov dx, msg_phase_128
    call phase_begin
    mov dx, fname_128
    mov word [phase_writes], 512
    mov word [phase_bytes], 128
    call run_write_body
    call phase_end
    ret

run_fat16_alloc_phase:
    mov dx, msg_phase_fat16
    call phase_begin
    mov dx, fname_alloc
    mov word [phase_writes], 256
    mov word [phase_bytes], 512
    call run_write_body
    call phase_end
    ret

run_write_body:
    mov [phase_name], dx
    mov dx, [phase_name]
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov ax, [phase_writes]
    mov [loop_count], ax
.write_loop:
    mov bx, [handle]
    mov dx, write_buf
    mov cx, [phase_bytes]
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, [phase_bytes]
    jne fail_write
    dec word [loop_count]
    jnz .write_loop

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

run_drive_switch_phase:
    PRINT_DOLLAR msg_phase_drive
    mov dx, fname_drive
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [drive_handle], ax

    mov dx, fname_mix
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [cd_handle], ax

    call counters_begin
    mov word [loop_count], 32
.switch_loop:
    mov bx, [drive_handle]
    mov dx, write_buf
    mov cx, 128
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 128
    jne fail_write

    mov bx, [cd_handle]
    mov dx, read_buf
    mov cx, 64
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 64
    jne fail_read

    dec word [loop_count]
    jnz .switch_loop

    mov bx, [drive_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    mov bx, [cd_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    call phase_end
    ret

run_metadata_phase:
    PRINT_DOLLAR msg_phase_meta
    mov dx, fname_meta
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, [handle]
    mov dx, one_byte
    mov cx, 1
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 1
    jne fail_write

    call counters_begin
    mov word [loop_count], 32
    mov word [meta_time], 0x4000
.meta_loop:
    mov bx, [handle]
    mov ax, 0x5701
    mov cx, [meta_time]
    mov dx, 0x5A21
    int 0x21
    jc fail_metadata

    mov bx, [handle]
    mov ah, 0x68
    int 0x21
    jc fail_metadata

    inc word [meta_time]
    dec word [loop_count]
    jnz .meta_loop

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    call phase_end
    ret

run_cd_mix_phase:
    PRINT_DOLLAR msg_phase_cd
    mov dx, fname_mix
    mov ax, 0x3D00
    int 0x21
    jc fail_open
    mov [cd_handle], ax

    call counters_begin
    mov word [loop_count], 96
    mov word [cd_offset], 0
.cd_loop:
    mov bx, [cd_handle]
    mov dx, read_buf
    mov cx, 64
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, 64
    jne fail_read

    mov di, [cd_offset]
    call verify64
    jc fail_verify
    add word [cd_offset], 64
    dec word [loop_count]
    jnz .cd_loop

    mov bx, [cd_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    call phase_end
    ret

phase_begin:
    mov ah, 0x09
    int 0x21
counters_begin:
    call perf_reset
    call read_ticks
    mov [tick_start_lo], dx
    ret

phase_end:
    call read_ticks
    sub dx, [tick_start_lo]
    mov [elapsed_ticks], dx
    call print_ticks
    call perf_print
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

fail_create:
    mov dx, msg_fail_create
    jmp fail
fail_open:
    mov dx, msg_fail_open
    jmp fail
fail_write:
    mov dx, msg_fail_write
    jmp fail
fail_read:
    mov dx, msg_fail_read
    jmp fail
fail_close:
    mov dx, msg_fail_close
    jmp fail
fail_metadata:
    mov dx, msg_fail_metadata
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

msg_start: db "BENCH: PERFIO", 13, 10, "$"
msg_phase_512: db "BENCH: WRITE512", 13, 10, "$"
msg_phase_128: db "BENCH: WRITE128", 13, 10, "$"
msg_phase_drive: db "BENCH: DRIVESW", 13, 10, "$"
msg_phase_fat16: db "BENCH: FAT16ALLOC", 13, 10, "$"
msg_phase_meta: db "BENCH: METADATA", 13, 10, "$"
msg_phase_cd: db "BENCH: CDMIX64", 13, 10, "$"
msg_ticks: db "TICKS=", "$"
msg_crlf_dollar: db 13, 10, "$"
msg_pass: db "PASS: PERFIO", 13, 10, "$"
msg_fail_create: db "FAIL: PERFIO CREATE", 13, 10, "$"
msg_fail_open: db "FAIL: PERFIO OPEN", 13, 10, "$"
msg_fail_write: db "FAIL: PERFIO WRITE", 13, 10, "$"
msg_fail_read: db "FAIL: PERFIO READ", 13, 10, "$"
msg_fail_close: db "FAIL: PERFIO CLOSE", 13, 10, "$"
msg_fail_metadata: db "FAIL: PERFIO METADATA", 13, 10, "$"
msg_fail_verify: db "FAIL: PERFIO VERIFY", 13, 10, "$"
msg_fail_perfapi: db "FAIL: PERFIO PERFAPI", 13, 10, "$"

fname_512: db "C:\PERF512.DAT", 0
fname_128: db "C:\PERF128.DAT", 0
fname_drive: db "C:\DRIVESW.DAT", 0
fname_alloc: db "C:\ALLOC.DAT", 0
fname_meta: db "C:\META.DAT", 0
fname_mix: db "D:\MIX.BIN", 0

handle: dw 0
drive_handle: dw 0
cd_handle: dw 0
phase_name: dw 0
phase_writes: dw 0
phase_bytes: dw 0
loop_count: dw 0
tick_start_lo: dw 0
elapsed_ticks: dw 0
meta_time: dw 0
cd_offset: dw 0
one_byte: db 0xA5
write_buf: times 512 db 0x5A
read_buf: times 64 db 0
