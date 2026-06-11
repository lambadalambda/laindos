[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, base_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir_base

    mov dx, base_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd_base

    mov si, expected_base
    call check_curdir_default
    jc fail_curdir_base

    mov si, expected_base
    call check_curdir_a
    jc fail_curdir_a

    mov dx, empty_path
    mov ah, 0x3B
    int 0x21
    jnc fail_cd_empty
    cmp ax, 3
    jne fail_cd_empty
    mov si, expected_base
    call check_curdir_default
    jc fail_cd_empty

    mov dx, root_file
    mov ah, 0x3B
    int 0x21
    jnc fail_cd_file
    cmp ax, 3
    jne fail_cd_file
    mov si, expected_base
    call check_curdir_default
    jc fail_cd_file

    mov dx, bad_drive_root
    mov ah, 0x3B
    int 0x21
    jnc fail_cd_drive
    cmp ax, 15
    jne fail_cd_drive
    mov si, expected_base
    call check_curdir_default
    jc fail_cd_drive

    mov dx, empty_path
    mov ah, 0x39
    int 0x21
    jnc fail_mkdir_empty
    cmp ax, 3
    jne fail_mkdir_empty

    mov dx, bad_drive_mkdir
    mov ah, 0x39
    int 0x21
    jnc fail_mkdir_drive
    cmp ax, 15
    jne fail_mkdir_drive

    mov dx, empty_path
    mov ah, 0x3A
    int 0x21
    jnc fail_rmdir_empty
    cmp ax, 3
    jne fail_rmdir_empty

    mov dx, bad_drive_rmdir
    mov ah, 0x3A
    int 0x21
    jnc fail_rmdir_drive
    cmp ax, 15
    jne fail_rmdir_drive

    mov byte [curdir_buf], 'X'
    mov byte [curdir_buf + 1], 0
    mov si, curdir_buf
    mov dl, 26
    mov ah, 0x47
    int 0x21
    jnc fail_getcwd_drive
    cmp ax, 15
    jne fail_getcwd_drive
    cmp byte [curdir_buf], 'X'
    jne fail_getcwd_drive

    mov si, expected_base
    call check_curdir_default
    jc fail_curdir_base

    mov dx, root_path
    mov ah, 0x3B
    int 0x21
    jc fail_cd_root

    mov dx, base_dir_slash
    mov ah, 0x3B
    int 0x21
    jc fail_cd_trailing
    mov si, expected_base
    call check_curdir_default
    jc fail_cd_trailing

    mov dx, file_slash
    mov ah, 0x3B
    int 0x21
    jnc fail_cd_file_trailing
    cmp ax, 3
    jne fail_cd_file_trailing

    mov dx, root_path
    mov ah, 0x3B
    int 0x21
    jc fail_cd_root

    mov dx, base_dir
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir_base

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

check_curdir_default:
    mov [expected_ptr], si
    xor dl, dl
    jmp check_curdir

check_curdir_a:
    mov [expected_ptr], si
    mov dl, 1

check_curdir:
    mov si, curdir_buf
    mov ah, 0x47
    int 0x21
    jc .bad
    mov si, [expected_ptr]
    mov di, curdir_buf
    call check_zstr
    ret
.bad:
    stc
    ret

check_zstr:
    lodsb
    cmp al, [di]
    jne .bad
    inc di
    test al, al
    jnz check_zstr
    clc
    ret
.bad:
    stc
    ret

fail_mkdir_base:
    mov dx, fail_mkdir_base_msg
    jmp fail
fail_cd_base:
    mov dx, fail_cd_base_msg
    jmp fail
fail_curdir_base:
    mov dx, fail_curdir_base_msg
    jmp fail
fail_curdir_a:
    mov dx, fail_curdir_a_msg
    jmp fail
fail_cd_empty:
    mov dx, fail_cd_empty_msg
    jmp fail
fail_cd_file:
    mov dx, fail_cd_file_msg
    jmp fail
fail_cd_drive:
    mov dx, fail_cd_drive_msg
    jmp fail
fail_mkdir_empty:
    mov dx, fail_mkdir_empty_msg
    jmp fail
fail_mkdir_drive:
    mov dx, fail_mkdir_drive_msg
    jmp fail
fail_rmdir_empty:
    mov dx, fail_rmdir_empty_msg
    jmp fail
fail_rmdir_drive:
    mov dx, fail_rmdir_drive_msg
    jmp fail
fail_getcwd_drive:
    mov dx, fail_getcwd_drive_msg
    jmp fail
fail_cd_root:
    mov dx, fail_cd_root_msg
    jmp fail
fail_cd_trailing:
    mov dx, fail_cd_trailing_msg
    jmp fail
fail_cd_file_trailing:
    mov dx, fail_cd_file_trailing_msg
    jmp fail
fail_rmdir_base:
    mov dx, fail_rmdir_base_msg

fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

base_dir: db "EDGEBASE", 0
root_file: db "\DIREDGE.COM", 0
bad_drive_root: db "Z:\", 0
bad_drive_mkdir: db "Z:\BADMK", 0
bad_drive_rmdir: db "Z:\BADRD", 0
empty_path: db 0
root_path: db "\", 0
base_dir_slash: db "EDGEBASE\", 0
file_slash: db "\DIREDGE.COM\", 0
expected_base: db "EDGEBASE", 0
pass_msg: db "PASS: DIREDGE", 13, 10, "$"
fail_mkdir_base_msg: db "FAIL: DIREDGE MKDIR BASE", 13, 10, "$"
fail_cd_base_msg: db "FAIL: DIREDGE CD BASE", 13, 10, "$"
fail_curdir_base_msg: db "FAIL: DIREDGE CURDIR BASE", 13, 10, "$"
fail_curdir_a_msg: db "FAIL: DIREDGE CURDIR A", 13, 10, "$"
fail_cd_empty_msg: db "FAIL: DIREDGE CD EMPTY", 13, 10, "$"
fail_cd_file_msg: db "FAIL: DIREDGE CD FILE", 13, 10, "$"
fail_cd_drive_msg: db "FAIL: DIREDGE CD DRIVE", 13, 10, "$"
fail_mkdir_empty_msg: db "FAIL: DIREDGE MKDIR EMPTY", 13, 10, "$"
fail_mkdir_drive_msg: db "FAIL: DIREDGE MKDIR DRIVE", 13, 10, "$"
fail_rmdir_empty_msg: db "FAIL: DIREDGE RMDIR EMPTY", 13, 10, "$"
fail_rmdir_drive_msg: db "FAIL: DIREDGE RMDIR DRIVE", 13, 10, "$"
fail_getcwd_drive_msg: db "FAIL: DIREDGE GETCWD DRIVE", 13, 10, "$"
fail_cd_root_msg: db "FAIL: DIREDGE CD ROOT", 13, 10, "$"
fail_cd_trailing_msg: db "FAIL: DIREDGE CD TRAILING", 13, 10, "$"
fail_cd_file_trailing_msg: db "FAIL: DIREDGE CD FILE TRAILING", 13, 10, "$"
fail_rmdir_base_msg: db "FAIL: DIREDGE RMDIR BASE", 13, 10, "$"
expected_ptr: dw 0
curdir_buf: times 64 db 0
