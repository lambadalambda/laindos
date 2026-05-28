[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov bx, 20
    mov ah, 0x67
    int 0x21
    jc fail_handles

    mov bx, 40
    mov ah, 0x67
    int 0x21
    jc fail_handles

    mov dx, new_name
    xor cx, cx
    mov ah, 0x5B
    int 0x21
    jc fail_create_new
    mov [new_handle], ax

    mov bx, [new_handle]
    mov dx, new_data
    mov cx, new_data_len
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, new_data_len
    jne fail_write

    mov bx, [new_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, new_name
    xor cx, cx
    mov ah, 0x5B
    int 0x21
    jnc fail_exists
    cmp ax, 80
    jne fail_exists

    mov dx, seed_temp_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_seed
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, temp_path
    xor cx, cx
    mov ah, 0x5A
    int 0x21
    jc fail_temp
    mov [temp_handle], ax

    mov si, temp_path
    mov di, seed_temp_name
    call strcmp
    jnc fail_temp_collision

    mov si, temp_path
    mov di, saved_temp_path
    call strcpy

    mov bx, [temp_handle]
    mov dx, temp_data
    mov cx, temp_data_len
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, temp_data_len
    jne fail_write

    mov bx, [temp_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, temp_path
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open_temp
    mov [temp_handle], ax

    mov bx, [temp_handle]
    mov dx, read_buf
    mov cx, temp_data_len
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, temp_data_len
    jne fail_read
    mov si, temp_data
    mov di, read_buf
    mov cx, temp_data_len
    repe cmpsb
    jne fail_read

    mov bx, [temp_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, temp_path2
    xor cx, cx
    mov ah, 0x5A
    int 0x21
    jc fail_temp
    mov [temp_handle], ax

    mov si, temp_path2
    mov di, saved_temp_path
    call strcmp
    jnc fail_temp_collision

    mov bx, [temp_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, bad_temp_path
    xor cx, cx
    mov ah, 0x5A
    int 0x21
    jnc fail_bad_temp
    cmp byte [bad_temp_tail], 0
    jne fail_temp_restore

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

strcpy:
    lodsb
    stosb
    test al, al
    jnz strcpy
    ret

strcmp:
    lodsb
    scasb
    jne .diff
    test al, al
    jnz strcmp
    clc
    ret
.diff:
    stc
    ret

fail_handles:
    mov dx, fail_handles_msg
    jmp fail
fail_create_new:
    mov dx, fail_create_new_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_exists:
    mov dx, fail_exists_msg
    jmp fail
fail_seed:
    mov dx, fail_seed_msg
    jmp fail
fail_temp:
    mov dx, fail_temp_msg
    jmp fail
fail_temp_collision:
    mov dx, fail_temp_collision_msg
    jmp fail
fail_open_temp:
    mov dx, fail_open_temp_msg
    jmp fail
fail_bad_temp:
    mov dx, fail_bad_temp_msg
    jmp fail
fail_temp_restore:
    mov dx, fail_temp_restore_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

new_name: db 'NEWFILE.DAT', 0
seed_temp_name: db 'A:\LD0000.TMP', 0
temp_path: db 'A:\', 13 dup(0)
temp_path2: db 'A:\', 13 dup(0)
bad_temp_path: db 'NOPE\'
bad_temp_tail: db 0
times 13 db 0
saved_temp_path: times 16 db 0
new_data: db 'CREATE-NEW'
new_data_len equ $ - new_data
temp_data: db 'TEMP-OK'
temp_data_len equ $ - temp_data
new_handle: dw 0
temp_handle: dw 0
read_buf: times temp_data_len db 0

pass_msg: db 'PASS: CREATEAPI', 13, 10, '$'
fail_handles_msg: db 'FAIL: CREATEAPI AH67', 13, 10, '$'
fail_create_new_msg: db 'FAIL: CREATEAPI AH5B', 13, 10, '$'
fail_write_msg: db 'FAIL: CREATEAPI WRITE', 13, 10, '$'
fail_close_msg: db 'FAIL: CREATEAPI CLOSE', 13, 10, '$'
fail_exists_msg: db 'FAIL: CREATEAPI EXISTS', 13, 10, '$'
fail_seed_msg: db 'FAIL: CREATEAPI SEED', 13, 10, '$'
fail_temp_msg: db 'FAIL: CREATEAPI AH5A', 13, 10, '$'
fail_temp_collision_msg: db 'FAIL: CREATEAPI TEMP COLLISION', 13, 10, '$'
fail_open_temp_msg: db 'FAIL: CREATEAPI TEMP OPEN', 13, 10, '$'
fail_bad_temp_msg: db 'FAIL: CREATEAPI BAD TEMP', 13, 10, '$'
fail_temp_restore_msg: db 'FAIL: CREATEAPI TEMP RESTORE', 13, 10, '$'
fail_read_msg: db 'FAIL: CREATEAPI READ', 13, 10, '$'
