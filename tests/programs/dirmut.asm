[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov dx, dta
    mov ah, 0x1A
    int 0x21

    mov dx, visible_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, visible_dir
    mov ah, 0x39
    int 0x21
    jnc fail_mkdir_exists

    mov dx, visible_dir
    mov cx, 0x10
    mov ah, 0x4E
    int 0x21
    jc fail_find
    test byte [dta + 21], 0x10
    jz fail_find

    mov dx, visible_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, root_path
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, empty_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, empty_dir
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir


    mov dx, empty_dir
    mov ah, 0x3B
    int 0x21
    jnc fail_rmdir

    mov dx, dirmut_file
    mov ah, 0x3A
    int 0x21
    jnc fail_rmdir_file

    mov dx, curdir_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, curdir_dir
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, curdir_abs
    mov ah, 0x3A
    int 0x21
    jnc fail_rmdir_current

    mov dx, root_path
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, curdir_dir
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir

    mov dx, nonempty_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, nonempty_file
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, payload
    mov cx, payload_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, payload_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, nonempty_dir
    mov ah, 0x3A
    int 0x21
    jnc fail_nonempty

    mov dx, nonempty_file
    mov ah, 0x41
    int 0x21
    jc fail_delete

    mov dx, nonempty_dir
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir

    mov dx, parent_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, child_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, parent_dir
    mov ah, 0x3A
    int 0x21
    jnc fail_nonempty

    mov dx, child_dir
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir

    mov dx, parent_dir
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir

    mov dx, subdir_child
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, subdir_child
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, root_path
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, subdir_child
    mov ah, 0x3A
    int 0x21
    jc fail_rmdir

    mov dx, keep_dir
    mov ah, 0x39
    int 0x21
    jc fail_mkdir

    mov dx, keep_child
    mov ah, 0x39
    int 0x21
    jc fail_mkdir


    call fill_root_directory

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_mkdir:
    mov dx, fail_mkdir_msg
    jmp print_fail
fail_mkdir_exists:
    mov dx, fail_mkdir_exists_msg
    jmp print_fail
fail_find:
    mov dx, fail_find_msg
    jmp print_fail
fail_cd:
    mov dx, fail_cd_msg
    jmp print_fail
fail_rmdir:
    mov dx, fail_rmdir_msg
    jmp print_fail
fail_rmdir_file:
    mov dx, fail_rmdir_file_msg
    jmp print_fail
fail_rmdir_current:
    mov dx, fail_rmdir_current_msg
    jmp print_fail
fail_nonempty:
    mov dx, fail_nonempty_msg
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
fail_delete:
    mov dx, fail_delete_msg
    jmp print_fail
fail_root_full:
    mov dx, fail_root_full_msg
print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

fill_root_directory:
    mov word [fill_count], 0
.loop:
    call make_fill_name
    mov dx, fill_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc .full
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close
    inc word [fill_count]
    jmp .loop
.full:
    cmp word [fill_count], 200
    jb fail_root_full
    mov dx, too_full_dir
    mov ah, 0x39
    int 0x21
    jnc fail_root_full
    ret

make_fill_name:
    mov ax, [fill_count]
    mov di, fill_name + 7
    mov cx, 4
.digit:
    xor dx, dx
    mov bx, 10
    div bx
    add dl, '0'
    mov [di], dl
    dec di
    loop .digit
    ret

visible_dir: db "VISIBLE", 0
empty_dir: db "EMPTY", 0
dirmut_file: db "DIRMUT.COM", 0
curdir_dir: db "CURDIR", 0
curdir_abs: db "\CURDIR", 0
nonempty_dir: db "NONEMPTY", 0
nonempty_file: db "NONEMPTY\FILE.DAT", 0
parent_dir: db "PARENT", 0
child_dir: db "PARENT\CHILD", 0
subdir_child: db "MIDEMO\MAKEDIR", 0
keep_dir: db "KEEP", 0
keep_child: db "KEEP\NESTED", 0
too_full_dir: db "TOOFULL", 0
root_path: db "\", 0
fill_name: db "FILL0000.TMP", 0
payload: db "directory payload", 13, 10
payload_size equ $ - payload
pass_msg: db "PASS: DIRMUT", 13, 10, "$"
fail_mkdir_msg: db "FAIL: MKDIR", 13, 10, "$"
fail_mkdir_exists_msg: db "FAIL: MKDIR EXISTS", 13, 10, "$"
fail_find_msg: db "FAIL: FINDDIR", 13, 10, "$"
fail_cd_msg: db "FAIL: CDDIR", 13, 10, "$"
fail_rmdir_msg: db "FAIL: RMDIR", 13, 10, "$"
fail_rmdir_file_msg: db "FAIL: RMDIR FILE", 13, 10, "$"
fail_rmdir_current_msg: db "FAIL: RMDIR CURRENT", 13, 10, "$"
fail_nonempty_msg: db "FAIL: RMDIR NONEMPTY", 13, 10, "$"
fail_create_msg: db "FAIL: CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: WRITE", 13, 10, "$"
fail_close_msg: db "FAIL: CLOSE", 13, 10, "$"
fail_delete_msg: db "FAIL: DELETE", 13, 10, "$"
fail_root_full_msg: db "FAIL: ROOT FULL", 13, 10, "$"
handle: dw 0
fill_count: dw 0
dta: times 64 db 0
