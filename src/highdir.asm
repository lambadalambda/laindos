[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, seed_path
    mov ax, 0x3D00
    int 0x21
    jc fail_open_seed
    mov [handle], ax

    mov bx, ax
    mov dx, read_buf
    mov cx, seed_size
    mov ah, 0x3F
    int 0x21
    jc fail_read_seed
    cmp ax, seed_size
    jne fail_read_seed
    mov si, read_buf
    mov di, seed_data
    mov cx, seed_size
    repe cmpsb
    jne fail_read_seed

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, temp_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, temp_dir
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir

    mov dx, delete_path
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, delete_data
    mov cx, delete_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, delete_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, delete_path
    mov ah, 0x41
    int 0x21
    jc fail_delete

    mov dx, out_path
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, out_data
    mov cx, out_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, out_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, out_path
    push ds
    pop es
    mov di, renamed_path
    mov ah, 0x56
    int 0x21
    jc fail_rename

    mov dx, renamed_path
    mov ax, 0x3D00
    int 0x21
    jc fail_open_out
    mov [handle], ax

    mov bx, ax
    mov dx, read_buf
    mov cx, out_size
    mov ah, 0x3F
    int 0x21
    jc fail_read_out
    cmp ax, out_size
    jne fail_read_out
    mov si, read_buf
    mov di, out_data
    mov cx, out_size
    repe cmpsb
    jne fail_read_out

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, renamed_path
    mov cx, 0x02
    mov ax, 0x4301
    int 0x21
    jc fail_attr

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_open_seed:
    mov dx, fail_open_seed_msg
    jmp print_fail
fail_read_seed:
    mov dx, fail_read_seed_msg
    jmp print_fail
fail_create:
    mov dx, fail_create_msg
    jmp print_fail
fail_write:
    mov dx, fail_write_msg
    jmp print_fail
fail_close:
    mov dx, fail_close_msg
    jmp print_fail
fail_mkdir:
    mov dx, fail_mkdir_msg
    jmp print_fail
fail_rmdir:
    mov dx, fail_rmdir_msg
    jmp print_fail
fail_delete:
    mov dx, fail_delete_msg
    jmp print_fail
fail_rename:
    mov dx, fail_rename_msg
    jmp print_fail
fail_open_out:
    mov dx, fail_open_out_msg
    jmp print_fail
fail_read_out:
    mov dx, fail_read_out_msg
    jmp print_fail
fail_attr:
    mov dx, fail_attr_msg

print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

seed_path db 'HIDIR\SEED.DAT', 0
temp_dir db 'HIDIR\SUBTEMP', 0
delete_path db 'HIDIR\DELME.DAT', 0
out_path db 'HIDIR\HIGHOUT.DAT', 0
renamed_path db 'HIDIR\RENAMED.DAT', 0
seed_data db 'seed-high-dir'
seed_size equ $ - seed_data
delete_data db 'delete-me'
delete_size equ $ - delete_data
out_data db 'high-lba-dir-write'
out_size equ $ - out_data
pass_msg db 'PASS: HIGHDIR', 13, 10, '$'
fail_open_seed_msg db 'FAIL: OPEN SEED', 13, 10, '$'
fail_read_seed_msg db 'FAIL: READ SEED', 13, 10, '$'
fail_create_msg db 'FAIL: CREATE', 13, 10, '$'
fail_write_msg db 'FAIL: WRITE', 13, 10, '$'
fail_close_msg db 'FAIL: CLOSE', 13, 10, '$'
fail_mkdir_msg db 'FAIL: MKDIR', 13, 10, '$'
fail_rmdir_msg db 'FAIL: RMDIR', 13, 10, '$'
fail_delete_msg db 'FAIL: DELETE', 13, 10, '$'
fail_rename_msg db 'FAIL: RENAME', 13, 10, '$'
fail_open_out_msg db 'FAIL: OPEN OUT', 13, 10, '$'
fail_read_out_msg db 'FAIL: READ OUT', 13, 10, '$'
fail_attr_msg db 'FAIL: ATTR', 13, 10, '$'
handle dw 0
read_buf times 64 db 0
