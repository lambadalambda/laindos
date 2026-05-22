[bits 16]
[org 0x0100]

start:
    push cs
    pop ds
    call fill_pattern

    mov dx, src_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, pattern
    mov cx, pattern_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, pattern_size
    jne fail_write

    mov bx, [handle]
    mov cx, 0x1234
    mov dx, 0x5678
    mov ax, 0x5701
    int 0x21
    jc fail_date

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, src_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov ax, 0x5700
    int 0x21
    jc fail_date
    cmp cx, 0x1234
    jne fail_date
    cmp dx, 0x5678
    jne fail_date

    mov bx, [handle]
    mov dx, read_buf
    mov cx, pattern_size
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, pattern_size
    jne fail_read

    call compare_pattern
    jc fail_compare

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    push cs
    pop es
    mov dx, src_name
    mov di, dst_name
    mov ah, 0x56
    int 0x21
    jc fail_rename

    mov dx, src_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_rename

    mov dx, dst_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_rename
    mov [handle], ax

    mov bx, ax
    mov dx, read_buf
    mov cx, pattern_size
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, pattern_size
    jne fail_read
    call compare_pattern
    jc fail_compare

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, dst_name
    mov ah, 0x41
    int 0x21
    jc fail_delete

    mov dx, dst_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_delete

    mov dx, reuse_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, pattern
    mov cx, pattern_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, pattern_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, readonly_name
    mov cx, 1
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, readonly_name
    mov ah, 0x41
    int 0x21
    jnc fail_delete_readonly

    mov dx, subdir_name
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, sub_multi_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jnc fail_path

    mov dx, sub_src_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, pattern
    mov cx, pattern_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, pattern_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, sub_src_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov dx, read_buf
    mov cx, pattern_size
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, pattern_size
    jne fail_read
    call compare_pattern
    jc fail_compare

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    push cs
    pop es
    mov dx, sub_src_name
    mov di, sub_done_name
    mov ah, 0x56
    int 0x21
    jc fail_rename

    mov dx, sub_src_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_rename

    mov dx, sub_done_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_rename
    mov [handle], ax

    mov bx, ax
    mov dx, read_buf
    mov cx, pattern_size
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, pattern_size
    jne fail_read
    call compare_pattern
    jc fail_compare

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, sub_done_name
    mov ah, 0x41
    int 0x21
    jc fail_delete

    mov dx, sub_done_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jnc fail_delete

    mov dx, sub_reuse_name
    xor cx, cx
    mov ah, 0x3C
    int 0x21
    jc fail_create
    mov [handle], ax

    mov bx, ax
    mov dx, pattern
    mov cx, pattern_size
    mov ah, 0x40
    int 0x21
    jc fail_write
    cmp ax, pattern_size
    jne fail_write

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, subtest_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, ax
    mov dx, read_buf
    mov cx, subtest_size
    mov ah, 0x3F
    int 0x21
    jc fail_read
    cmp ax, subtest_size
    jne fail_read
    call compare_subtest
    jc fail_compare

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, root_path
    mov ah, 0x3B
    int 0x21
    jc fail_cd

    mov dx, reuse_name
    xor al, al
    mov ah, 0x3D
    int 0x21
    jc fail_open
    mov [handle], ax

    mov bx, [handle]
    mov ah, 0x3E
    int 0x21
    jc fail_close

    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fill_pattern:
    push cs
    pop es
    mov di, pattern
    xor ax, ax
    mov cx, pattern_size
.loop:
    stosb
    inc al
    loop .loop
    ret

compare_pattern:
    push cs
    pop es
    mov si, pattern
    mov di, read_buf
    mov cx, pattern_size
.loop:
    cmpsb
    jne .bad
    loop .loop
    clc
    ret
.bad:
    stc
    ret

compare_subtest:
    push cs
    pop es
    mov si, subtest_text
    mov di, read_buf
    mov cx, subtest_size
.loop:
    cmpsb
    jne .bad
    loop .loop
    clc
    ret
.bad:
    stc
    ret

fail_create:
    mov dx, fail_create_msg
    jmp print_fail
fail_write:
    mov dx, fail_write_msg
    jmp print_fail
fail_close:
    mov dx, fail_close_msg
    jmp print_fail
fail_open:
    mov dx, fail_open_msg
    jmp print_fail
fail_read:
    mov dx, fail_read_msg
    jmp print_fail
fail_compare:
    mov dx, fail_compare_msg
    jmp print_fail
fail_rename:
    mov dx, fail_rename_msg
    jmp print_fail
fail_date:
    mov dx, fail_date_msg
    jmp print_fail
fail_delete:
    mov dx, fail_delete_msg
    jmp print_fail
fail_delete_readonly:
    mov dx, fail_delete_readonly_msg
    jmp print_fail
fail_cd:
    mov dx, fail_cd_msg
    jmp print_fail
fail_path:
    mov dx, fail_path_msg
print_fail:
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

src_name: db "SAVEWR.DAT", 0
dst_name: db "SAVEDONE.DAT", 0
reuse_name: db "REUSED.DAT", 0
readonly_name: db "READONLY.DAT", 0
subdir_name: db "MIDEMO", 0
root_path: db "\", 0
subtest_name: db "SUBTEST.DAT", 0
sub_src_name: db "SUBSAVE.DAT", 0
sub_done_name: db "SUBDONE.DAT", 0
sub_reuse_name: db "SUBUSED.DAT", 0
sub_multi_name: db "MIDEMO\BOGUS.DAT", 0
subtest_text: db "Hello from MIDEMO subdirectory!", 10
subtest_size equ $ - subtest_text
pass_msg: db "PASS: SAVEWRITE", 13, 10, "$"
fail_create_msg: db "FAIL: CREATE", 13, 10, "$"
fail_write_msg: db "FAIL: WRITEFILE", 13, 10, "$"
fail_close_msg: db "FAIL: CLOSE", 13, 10, "$"
fail_open_msg: db "FAIL: OPEN", 13, 10, "$"
fail_read_msg: db "FAIL: READ", 13, 10, "$"
fail_compare_msg: db "FAIL: COMPARE", 13, 10, "$"
fail_rename_msg: db "FAIL: RENAME", 13, 10, "$"
fail_date_msg: db "FAIL: DATE", 13, 10, "$"
fail_delete_msg: db "FAIL: DELETE", 13, 10, "$"
fail_delete_readonly_msg: db "FAIL: DELETE READONLY", 13, 10, "$"
fail_cd_msg: db "FAIL: CD", 13, 10, "$"
fail_path_msg: db "FAIL: PATH", 13, 10, "$"
handle: dw 0
pattern_size equ 700
pattern: times pattern_size db 0
read_buf: times pattern_size db 0
