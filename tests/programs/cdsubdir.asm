[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x0E
    mov dl, 3
    int 0x21
    cmp al, 4
    jb fail_select

    mov dx, cd_dir_path
    mov ah, 0x3B
    int 0x21
    jc fail_chdir

    mov ax, 0x4300
    mov dx, relative_attr_path
    int 0x21
    jc fail_attr_file
    test cx, 0x0010
    jnz fail_attr_file
    test cx, 0x0001
    jz fail_attr_file

    mov ax, 0x4300
    mov dx, cd_dir_path
    int 0x21
    jc fail_attr_dir
    test cx, 0x0010
    jz fail_attr_dir
    test cx, 0x0001
    jz fail_attr_dir

    mov ax, 0x3D00
    mov dx, dot_relative_path
    int 0x21
    jc fail_dot_open
    mov bx, ax
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, cd_dot_dir_path
    mov ah, 0x3B
    int 0x21
    jc fail_chdir_dot

    mov ax, 0x3D00
    mov dx, read_path
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov cx, 64
    mov dx, buf
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, expected_len
    jne fail_read_len

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov ax, 0x3D00
    mov dx, read_path
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov ax, 0x4200
    xor cx, cx
    mov dx, 1
    int 0x21
    jc fail_seek

    mov bx, [handle]
    mov cx, expected_tail_len
    mov dx, buf + 65
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, expected_tail_len
    jne fail_read_len

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov si, expected
    mov di, buf
    mov cx, expected_len
    repe cmpsb
    jne fail_contents

    push cs
    pop es
    mov si, expected + 1
    mov di, buf + 65
    mov cx, expected_tail_len
    repe cmpsb
    jne fail_contents

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_select:
    mov dx, fail_select_msg
    jmp fail
fail_chdir:
    mov dx, fail_chdir_msg
    jmp fail
fail_attr_file:
    mov dx, fail_attr_file_msg
    jmp fail
fail_attr_dir:
    mov dx, fail_attr_dir_msg
    jmp fail
fail_dot_open:
    mov dx, fail_dot_open_msg
    jmp fail
fail_chdir_dot:
    mov dx, fail_chdir_dot_msg
    jmp fail
fail_open:
    mov dx, fail_open_msg
    jmp fail
fail_read:
    mov dx, fail_read_msg
    jmp fail
fail_read_len:
    mov dx, fail_read_len_msg
    jmp fail
fail_seek:
    mov dx, fail_seek_msg
    jmp fail
fail_close:
    mov dx, fail_close_msg
    jmp fail
fail_contents:
    mov dx, fail_contents_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

handle: dw 0
cd_dir_path: db 'D:\SUBDIR', 0
cd_dot_dir_path: db 'D:\SUBDIR\.', 0
relative_attr_path: db 'HELLO.TXT', 0
dot_relative_path: db '.\HELLO.TXT', 0
read_path: db 'D:\SUBDIR\HELLO.TXT', 0
expected: db 'Hello from a LainDOS CD-ROM subdirectory.', 13, 10
expected_len equ $ - expected
expected_tail_len equ expected_len - 1
pass_msg: db 'PASS: CDSUBDIR', 13, 10, '$'
fail_select_msg: db 'FAIL: CDSUBDIR SELECT', 13, 10, '$'
fail_chdir_msg: db 'FAIL: CDSUBDIR CHDIR', 13, 10, '$'
fail_attr_file_msg: db 'FAIL: CDSUBDIR ATTR FILE', 13, 10, '$'
fail_attr_dir_msg: db 'FAIL: CDSUBDIR ATTR DIR', 13, 10, '$'
fail_dot_open_msg: db 'FAIL: CDSUBDIR DOT OPEN', 13, 10, '$'
fail_chdir_dot_msg: db 'FAIL: CDSUBDIR CHDIR DOT', 13, 10, '$'
fail_open_msg: db 'FAIL: CDSUBDIR OPEN', 13, 10, '$'
fail_read_msg: db 'FAIL: CDSUBDIR READ', 13, 10, '$'
fail_read_len_msg: db 'FAIL: CDSUBDIR READ LEN', 13, 10, '$'
fail_seek_msg: db 'FAIL: CDSUBDIR SEEK', 13, 10, '$'
fail_close_msg: db 'FAIL: CDSUBDIR CLOSE', 13, 10, '$'
fail_contents_msg: db 'FAIL: CDSUBDIR CONTENTS', 13, 10, '$'
buf: times 128 db 0
