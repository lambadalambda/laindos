[bits 16]
[org 0x0100]

start:
    push cs
    pop ds

    mov ah, 0x19
    int 0x21
    cmp al, 2
    je hd_tests
    cmp al, 0
    je floppy_tests
    jmp fail_initial

floppy_tests:
    mov si, cwd_buf
    xor dl, dl
    mov ah, 0x47
    int 0x21
    jc fail_curdir_default
    cmp byte [cwd_buf], 0
    jne fail_curdir_default

    mov si, cwd_buf
    mov dl, 1
    mov ah, 0x47
    int 0x21
    jc fail_curdir_a
    cmp byte [cwd_buf], 0
    jne fail_curdir_a

    mov si, cwd_buf
    mov dl, 2
    mov ah, 0x47
    int 0x21
    jnc fail_curdir_invalid
    cmp ax, 0x000F
    jne fail_curdir_invalid

    mov dl, 0
    mov ah, 0x0E
    int 0x21
    cmp al, 1
    jne fail_select_count

    mov ah, 0x19
    int 0x21
    cmp al, 0
    jne fail_select_a

    xor dl, dl
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_diskfree_default

    mov dl, 1
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_diskfree_a

    mov dl, 2
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    jne fail_diskfree_invalid

    mov dl, 1
    mov ah, 0x0E
    int 0x21
    cmp al, 1
    jne fail_select_count

    mov ah, 0x19
    int 0x21
    cmp al, 0
    jne fail_select_unchanged

    jmp pass

hd_tests:

    mov si, cwd_buf
    xor dl, dl
    mov ah, 0x47
    int 0x21
    jc fail_curdir_default
    cmp byte [cwd_buf], 0
    jne fail_curdir_default

    mov si, cwd_buf
    mov dl, 3
    mov ah, 0x47
    int 0x21
    jc fail_curdir_c

    mov si, cwd_buf
    mov dl, 2
    mov ah, 0x47
    int 0x21
    jc fail_curdir_b

    mov si, cwd_buf
    mov dl, 4
    mov ah, 0x47
    int 0x21
    jnc fail_curdir_invalid
    cmp ax, 0x000F
    jne fail_curdir_invalid

    mov dl, 0
    mov ah, 0x0E
    int 0x21
    cmp al, 3
    jne fail_select_count

    mov ah, 0x19
    int 0x21
    cmp al, 0
    jne fail_select_a

    mov si, cwd_buf
    mov dl, 1
    mov ah, 0x47
    int 0x21
    jc fail_curdir_a

    mov dl, 3
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_diskfree_c

    mov dl, 2
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_diskfree_b

    xor dl, dl
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    je fail_diskfree_default

    mov dl, 4
    mov ah, 0x36
    int 0x21
    cmp ax, 0xFFFF
    jne fail_diskfree_invalid

    mov dl, 2
    mov ah, 0x0E
    int 0x21
    cmp al, 3
    jne fail_select_count

    mov ah, 0x19
    int 0x21
    cmp al, 2
    jne fail_select_c

    mov dl, 1
    mov ah, 0x0E
    int 0x21
    cmp al, 3
    jne fail_select_count

    mov ah, 0x19
    int 0x21
    cmp al, 1
    jne fail_select_b

    mov dl, 2
    mov ah, 0x0E
    int 0x21
    cmp al, 3
    jne fail_select_count

    mov dl, 3
    mov ah, 0x0E
    int 0x21
    cmp al, 3
    jne fail_select_count


    mov ah, 0x19
    int 0x21
    cmp al, 2
    jne fail_select_unchanged

pass:
    mov dx, pass_msg
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C00
    int 0x21

fail_initial:
    mov dx, fail_initial_msg
    jmp fail
fail_curdir_default:
    mov dx, fail_curdir_default_msg
    jmp fail
fail_curdir_c:
    mov dx, fail_curdir_c_msg
    jmp fail
fail_curdir_b:
    mov dx, fail_curdir_b_msg
    jmp fail
fail_curdir_a:
    mov dx, fail_curdir_a_msg
    jmp fail
fail_curdir_invalid:
    mov dx, fail_curdir_invalid_msg
    jmp fail
fail_select_count:
    mov dx, fail_select_count_msg
    jmp fail
fail_select_a:
    mov dx, fail_select_a_msg
    jmp fail
fail_select_b:
    mov dx, fail_select_b_msg
    jmp fail
fail_select_c:
    mov dx, fail_select_c_msg
    jmp fail
fail_select_unchanged:
    mov dx, fail_select_unchanged_msg
    jmp fail
fail_diskfree_c:
    mov dx, fail_diskfree_c_msg
    jmp fail
fail_diskfree_b:
    mov dx, fail_diskfree_b_msg
    jmp fail
fail_diskfree_default:
    mov dx, fail_diskfree_default_msg
    jmp fail
fail_diskfree_a:
    mov dx, fail_diskfree_a_msg
    jmp fail
fail_diskfree_invalid:
    mov dx, fail_diskfree_invalid_msg
fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4C01
    int 0x21

cwd_buf: times 64 db 0
pass_msg: db "PASS: DRIVE", 13, 10, "$"
fail_initial_msg: db "FAIL: DRIVE INITIAL", 13, 10, "$"
fail_curdir_default_msg: db "FAIL: DRIVE CURDIR DEFAULT", 13, 10, "$"
fail_curdir_c_msg: db "FAIL: DRIVE CURDIR C", 13, 10, "$"
fail_curdir_b_msg: db "FAIL: DRIVE CURDIR B", 13, 10, "$"
fail_curdir_a_msg: db "FAIL: DRIVE CURDIR A", 13, 10, "$"
fail_curdir_invalid_msg: db "FAIL: DRIVE CURDIR INVALID", 13, 10, "$"
fail_select_count_msg: db "FAIL: DRIVE SELECT COUNT", 13, 10, "$"
fail_select_a_msg: db "FAIL: DRIVE SELECT A", 13, 10, "$"
fail_select_b_msg: db "FAIL: DRIVE SELECT B", 13, 10, "$"
fail_select_c_msg: db "FAIL: DRIVE SELECT C", 13, 10, "$"
fail_select_unchanged_msg: db "FAIL: DRIVE SELECT UNCHANGED", 13, 10, "$"
fail_diskfree_c_msg: db "FAIL: DRIVE DISKFREE C", 13, 10, "$"
fail_diskfree_b_msg: db "FAIL: DRIVE DISKFREE B", 13, 10, "$"
fail_diskfree_default_msg: db "FAIL: DRIVE DISKFREE DEFAULT", 13, 10, "$"
fail_diskfree_a_msg: db "FAIL: DRIVE DISKFREE A", 13, 10, "$"
fail_diskfree_invalid_msg: db "FAIL: DRIVE DISKFREE INVALID", 13, 10, "$"
