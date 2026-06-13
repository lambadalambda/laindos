%include "tests/programs/common.inc"

COM_START
    cld

    PRINT_DOLLAR msg_start
    call run_time_commit_phase
    call run_clean_commit_phase
    call run_clean_close_phase
    call run_overwrite_phase
    call run_temp_rename_phase
    call run_delete_old_phase
    call run_subdir_time_phase
    PASS_WITH msg_pass

run_time_commit_phase:
    PRINT_DOLLAR msg_phase_timecommit
    mov dx, fname_time
    call create_write_one
    mov [handle], ax
    call counters_begin
    mov word [loop_count], 32
    mov word [meta_time], 0x4100
.loop:
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
    jnz .loop
    call close_handle
    call phase_end
    ret

run_clean_commit_phase:
    PRINT_DOLLAR msg_phase_cleancommit
    mov dx, fname_commit
    call create_write_one
    mov [handle], ax
    mov bx, [handle]
    mov ah, 0x68
    int 0x21
    jc fail_metadata
    call counters_begin
    mov word [loop_count], 32
.loop:
    mov bx, [handle]
    mov ah, 0x68
    int 0x21
    jc fail_metadata
    dec word [loop_count]
    jnz .loop
    call close_handle
    call phase_end
    ret

run_clean_close_phase:
    PRINT_DOLLAR msg_phase_cleanclose
    mov dx, fname_close
    call create_write_one
    mov [handle], ax
    call close_handle
    mov dx, fname_close
    mov ax, 0x3D02
    int 0x21
    jc fail_open
    mov [handle], ax
    call counters_begin
    call close_handle
    call phase_end
    ret

run_overwrite_phase:
    PRINT_DOLLAR msg_phase_overwrite
    mov dx, fname_overwrite
    call create_write_512
    mov [handle], ax
    call close_handle
    mov dx, fname_overwrite
    mov ax, 0x3D02
    int 0x21
    jc fail_open
    mov [handle], ax
    call counters_begin
    call seek_start
    mov bx, [handle]
    mov dx, write_buf
    mov cx, 512
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 512
    jne fail_write
    mov bx, [handle]
    mov ah, 0x68
    int 0x21
    jc fail_metadata
    call close_handle
    call phase_end
    ret

run_temp_rename_phase:
    PRINT_DOLLAR msg_phase_temprename
    call counters_begin
    mov dx, fname_temp
    call create_write_512
    mov [handle], ax
    mov bx, [handle]
    mov ah, 0x68
    int 0x21
    jc fail_metadata
    call close_handle
    push cs
    pop es
    mov dx, fname_temp
    mov di, fname_final
    mov ah, 0x56
    int 0x21
    jc fail_rename
    call phase_end
    ret

run_delete_old_phase:
    PRINT_DOLLAR msg_phase_deleteold
    mov dx, fname_delete
    call create_write_512
    mov [handle], ax
    call close_handle
    call counters_begin
    mov dx, fname_delete
    mov ah, 0x41
    int 0x21
    jc fail_delete
    call phase_end
    ret

run_subdir_time_phase:
    PRINT_DOLLAR msg_phase_subdirtime
    mov dx, dirname_sub
    mov ah, 0x39
    int 0x21
    jc fail_mkdir
    mov dx, fname_sub
    call create_write_one
    mov [handle], ax
    call counters_begin
    mov word [loop_count], 32
    mov word [meta_time], 0x5100
.loop:
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
    jnz .loop
    call close_handle
    call phase_end
    ret

create_write_one:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax
    mov bx, ax
    mov dx, one_byte
    mov cx, 1
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 1
    jne fail_write
    mov ax, [handle]
    ret

create_write_512:
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax
    mov bx, ax
    mov dx, write_buf
    mov cx, 512
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, 512
    jne fail_write
    mov ax, [handle]
    ret

close_handle:
    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close
    ret

seek_start:
    mov bx, [handle]
    xor cx, cx
    xor dx, dx
    mov ax, 0x4200
    int 0x21
    jc fail_seek
    ret

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

fail_create:
    mov dx, msg_fail_create
    jmp fail
fail_open:
    mov dx, msg_fail_open
    jmp fail
fail_write:
    mov dx, msg_fail_write
    jmp fail
fail_close:
    mov dx, msg_fail_close
    jmp fail
fail_seek:
    mov dx, msg_fail_seek
    jmp fail
fail_metadata:
    mov dx, msg_fail_metadata
    jmp fail
fail_perfapi:
    mov dx, msg_fail_perfapi
    jmp fail
fail_rename:
    mov dx, msg_fail_rename
    jmp fail
fail_delete:
    mov dx, msg_fail_delete
    jmp fail
fail_mkdir:
    mov dx, msg_fail_mkdir
fail:
    mov ah, 0x09
    int 0x21
    EXIT_CODE 1

msg_start: db "BENCH: PERFMETA", 13, 10, "$"
msg_phase_timecommit: db "BENCH: TIMECOMMIT", 13, 10, "$"
msg_phase_cleancommit: db "BENCH: CLEANCOMMIT", 13, 10, "$"
msg_phase_cleanclose: db "BENCH: CLEANCLOSE", 13, 10, "$"
msg_phase_overwrite: db "BENCH: OVERWRITE", 13, 10, "$"
msg_phase_temprename: db "BENCH: TEMPRENAME", 13, 10, "$"
msg_phase_deleteold: db "BENCH: DELETEOLD", 13, 10, "$"
msg_phase_subdirtime: db "BENCH: SUBDIRTIME", 13, 10, "$"
msg_ticks: db "TICKS=", "$"
msg_crlf_dollar: db 13, 10, "$"
msg_pass: db "PASS: PERFMETA", 13, 10, "$"
msg_fail_create: db "FAIL: PERFMETA CREATE", 13, 10, "$"
msg_fail_open: db "FAIL: PERFMETA OPEN", 13, 10, "$"
msg_fail_write: db "FAIL: PERFMETA WRITE", 13, 10, "$"
msg_fail_close: db "FAIL: PERFMETA CLOSE", 13, 10, "$"
msg_fail_seek: db "FAIL: PERFMETA SEEK", 13, 10, "$"
msg_fail_metadata: db "FAIL: PERFMETA METADATA", 13, 10, "$"
msg_fail_perfapi: db "FAIL: PERFMETA PERFAPI", 13, 10, "$"
msg_fail_rename: db "FAIL: PERFMETA RENAME", 13, 10, "$"
msg_fail_delete: db "FAIL: PERFMETA DELETE", 13, 10, "$"
msg_fail_mkdir: db "FAIL: PERFMETA MKDIR", 13, 10, "$"

fname_time: db "C:\MTIME.DAT", 0
fname_commit: db "C:\MCOMMIT.DAT", 0
fname_close: db "C:\MCLOSE.DAT", 0
fname_overwrite: db "C:\MOVER.DAT", 0
fname_temp: db "C:\MTEMP.TMP", 0
fname_final: db "C:\MFINAL.SAV", 0
fname_delete: db "C:\MDEL.OLD", 0
dirname_sub: db "C:\MSUB", 0
fname_sub: db "C:\MSUB\MSUB.DAT", 0
handle: dw 0
loop_count: dw 0
tick_start_lo: dw 0
elapsed_ticks: dw 0
meta_time: dw 0
one_byte: db 0xA5
write_buf: times 512 db 0x7E
