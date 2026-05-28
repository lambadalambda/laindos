[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, filename
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [file_handle], ax

    mov bx, [file_handle]
    mov dx, data
    mov cx, data_len
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, data_len
    jne fail_write

    mov bx, [file_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, filename
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [file_handle], ax

    mov bx, [file_handle]
    mov ah, 0x45
    int 0x21
    jc fail_dup
    mov [dup_handle], ax

    mov bx, [file_handle]
    mov dl, 'A'
    call read_expect
    jc fail_shared_pos

    mov bx, [dup_handle]
    mov dl, 'B'
    call read_expect
    jc fail_shared_pos

    mov bx, [file_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, [dup_handle]
    mov dl, 'C'
    call read_expect
    jc fail_close_kept_dup

    mov bx, [dup_handle]
    mov cx, [file_handle]
    mov ah, 0x46
    int 0x21
    jc fail_force_dup

    mov bx, [file_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_force_revive

    mov bx, [dup_handle]
    mov cx, 8
    mov ah, 0x46
    int 0x21
    jc fail_force_dup
    mov word [force_handle], 8

    mov bx, [dup_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, [force_handle]
    mov dl, 'D'
    call read_expect
    jc fail_force_shared

    mov bx, [force_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, alt_filename
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [alt_handle], ax

    mov bx, [alt_handle]
    mov dx, alt_data
    mov cx, alt_data_len
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, alt_data_len
    jne fail_write

    mov bx, [alt_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, filename
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [file_handle], ax

    mov bx, [file_handle]
    mov ah, 0x45
    int 0x21
    jc fail_dup
    mov [old_alias_handle], ax

    mov dx, alt_filename
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [alt_handle], ax

    mov bx, [alt_handle]
    mov cx, [file_handle]
    mov ah, 0x46
    int 0x21
    jc fail_force_dup

    mov bx, [old_alias_handle]
    mov dl, 'A'
    call read_expect
    jc fail_force_preserve

    mov bx, [file_handle]
    mov dl, 'Z'
    call read_expect
    jc fail_force_shared

    mov bx, [old_alias_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, [file_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, [alt_handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov bx, 19
    mov ah, 0x45
    int 0x21
    jnc fail_bad_handle
    cmp ax, 6
    jne fail_bad_handle

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

read_expect:
    push dx
    mov ah, 0x3F
    mov cx, 1
    mov dx, read_buf
    int 0x21
    pop dx
    jc .err
    cmp ax, 1
    jne .err
    cmp [read_buf], dl
    jne .err
    clc
    ret
.err:
    stc
    ret

fail_create:
    mov dx, fail_create_msg
    jmp fail
fail_write:
    mov dx, fail_write_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_dup:
    mov dx, fail_dup_msg
    jmp fail
fail_shared_pos:
    mov dx, fail_shared_pos_msg
    jmp fail
fail_close_kept_dup:
    mov dx, fail_close_kept_dup_msg
    jmp fail
fail_force_dup:
    mov dx, fail_force_dup_msg
    jmp fail
fail_force_revive:
    mov dx, fail_force_revive_msg
    jmp fail
fail_force_shared:
    mov dx, fail_force_shared_msg
    jmp fail
fail_force_preserve:
    mov dx, fail_force_preserve_msg
    jmp fail
fail_bad_handle:
    mov dx, fail_bad_handle_msg
fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

filename: db "DUP.TXT", 0
data: db "ABCD"
data_len equ $ - data
alt_filename: db "ALT.TXT", 0
alt_data: db "Z"
alt_data_len equ $ - alt_data
file_handle: dw 0
dup_handle: dw 0
force_handle: dw 0
old_alias_handle: dw 0
alt_handle: dw 0
read_buf: db 0

pass_msg: db "PASS: DUP", 13, 10, "$"
fail_create_msg: db "FAIL: DUP CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: DUP WRITE", 13, 10, "$"
fail_close_msg: db "FAIL: DUP CLOSE", 13, 10, "$"
fail_open_msg: db "FAIL: DUP OPEN", 13, 10, "$"
fail_dup_msg: db "FAIL: DUP AH45", 13, 10, "$"
fail_shared_pos_msg: db "FAIL: DUP SHARED POS", 13, 10, "$"
fail_close_kept_dup_msg: db "FAIL: DUP CLOSE KEPT", 13, 10, "$"
fail_force_dup_msg: db "FAIL: DUP AH46", 13, 10, "$"
fail_force_revive_msg: db "FAIL: DUP FORCE REVIVE", 13, 10, "$"
fail_force_shared_msg: db "FAIL: DUP FORCE SHARED", 13, 10, "$"
fail_force_preserve_msg: db "FAIL: DUP FORCE PRESERVE", 13, 10, "$"
fail_bad_handle_msg: db "FAIL: DUP BAD HANDLE", 13, 10, "$"
